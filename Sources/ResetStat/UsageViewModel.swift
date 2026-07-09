import AppKit
import Foundation
import ResetStatCore
import SwiftUI
import UserNotifications

@MainActor
final class UsageViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
        case disabled
    }

    @Published private(set) var snapshot: ResetStatSnapshot?
    @Published private(set) var cursorSnapshot: CursorUsageSnapshot?
    @Published private(set) var desktopQuotaSnapshots: [DesktopQuotaSnapshot] = []
    @Published private(set) var openCodeGoSnapshot: OpenCodeGoUsageSnapshot?
    @Published private(set) var state: LoadState = .idle
    @Published private(set) var cursorState: LoadState = .idle
    @Published private(set) var desktopQuotaState: LoadState = .idle
    @Published private(set) var openCodeGoState: LoadState = .idle
    @Published private(set) var isRefreshing = false
    @Published private(set) var configuration: ResetStatConfiguration
    @Published var now = Date()
    @Published private(set) var lastFetchAt: [ProviderTab: Date] = [:]
    @Published private(set) var paceProjections: [ProviderTab: PaceProjection] = [:]

    private struct PaceSample {
        let percentUsed: Double
        let timestamp: Date
    }
    private var previousPaceSamples: [ProviderTab: PaceSample] = [:]

    var isProviderRefreshing: (ProviderTab) -> Bool {
        { self.refreshingProviders.contains($0) }
    }

    private let configurationStore: ResetStatConfigurationStore?
    private let service: CodexUsageFetching?
    private let cursorService: CursorUsageFetching?
    private let desktopQuotaService: DesktopQuotaFetching?
    private let openCodeGoService: OpenCodeGoUsageFetching?
    private var didStartLoops = false
    private var refreshingProviders: Set<ProviderTab> = []
    private let notificationCoordinator: NotificationCoordinator
    private var refreshTask: Task<Void, Never>?
    private var refreshLoopTask: Task<Void, Never>?
    private var clockLoopTask: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?

    convenience init(configurationStore: ResetStatConfigurationStore = ResetStatConfigurationStore()) {
        self.init(
            configurationStore: configurationStore,
            configuration: configurationStore.configuration,
            service: nil,
            cursorService: nil,
            desktopQuotaService: nil,
            openCodeGoService: nil,
            notificationCoordinator: NotificationCoordinator()
        )
    }

    init(
        configuration: ResetStatConfiguration = .defaults,
        service: CodexUsageFetching,
        cursorService: CursorUsageFetching,
        desktopQuotaService: DesktopQuotaFetching,
        openCodeGoService: OpenCodeGoUsageFetching,
        notificationCoordinator: NotificationCoordinator = NotificationCoordinator()
    ) {
        self.configurationStore = nil
        self.configuration = configuration
        self.service = service
        self.cursorService = cursorService
        self.desktopQuotaService = desktopQuotaService
        self.openCodeGoService = openCodeGoService
        self.notificationCoordinator = notificationCoordinator
    }

    private init(
        configurationStore: ResetStatConfigurationStore?,
        configuration: ResetStatConfiguration,
        service: CodexUsageFetching?,
        cursorService: CursorUsageFetching?,
        desktopQuotaService: DesktopQuotaFetching?,
        openCodeGoService: OpenCodeGoUsageFetching?,
        notificationCoordinator: NotificationCoordinator
    ) {
        self.configurationStore = configurationStore
        self.configuration = configuration
        self.service = service
        self.cursorService = cursorService
        self.desktopQuotaService = desktopQuotaService
        self.openCodeGoService = openCodeGoService
        self.notificationCoordinator = notificationCoordinator
    }

    func start() {
        guard !didStartLoops else { return }
        didStartLoops = true

        refreshLoopTask = Task { await refreshLoop() }
        clockLoopTask = Task { await clockLoop() }
        observeWorkspaceWake()
    }

    /// System sleep pauses `Task.sleep` (its clock stops while suspended) and
    /// can leave in-flight network requests hung after the network drops on
    /// wake. Without handling this, `isRefreshing` stays stuck `true`, which
    /// both pins the menu-bar refresh badges on and disables the per-provider
    /// refresh buttons until the app is restarted.
    private func observeWorkspaceWake() {
        wakeObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleSystemWake() }
        }
    }

    private func handleSystemWake() {
        now = Date()
        refreshTask?.cancel()
        refreshingProviders.removeAll()
        updateIsRefreshing()
        refreshTask = Task { await refresh() }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { updateIsRefreshing() }
        await withTaskGroup(of: Void.self) { group in
            if self.configuration.providers.codex.isEnabled {
                group.addTask { await self.refreshCodex() }
            } else {
                state = .disabled
                snapshot = nil
            }

            if self.configuration.providers.cursor.isEnabled {
                group.addTask { await self.refreshCursor() }
            } else {
                cursorState = .disabled
                cursorSnapshot = nil
            }

            if self.configuration.providers.devin.isEnabled {
                group.addTask { await self.refreshDesktopQuotas() }
            } else {
                desktopQuotaState = .disabled
                desktopQuotaSnapshots = []
            }

            if self.configuration.providers.openCodeGo.isEnabled {
                group.addTask { await self.refreshOpenCodeGo() }
            } else {
                openCodeGoState = .disabled
                openCodeGoSnapshot = nil
            }
        }
        await evaluateNotifications()
    }

    private func evaluateNotifications() async {
        let loadStates: [ProviderTab: LoadState] = [
            .codex: state,
            .cursor: cursorState,
            .devin: desktopQuotaState,
            .openCodeGo: openCodeGoState
        ]
        await notificationCoordinator.evaluate(
            summaries: providerSummaries,
            billingExpiries: billingExpiries,
            loadStates: loadStates,
            configuration: configuration.notifications,
            hidesProviderNames: hidesProviderNames,
            now: now
        )
    }

    @Published var notificationTestStatus: String?
    @Published var notificationNeedsSettings: Bool = false

    func setNotificationsEnabled(_ enabled: Bool) {
        updateConfiguration { $0.notifications.enabled = enabled }
        if enabled {
            Task { await requestNotificationAuthorization() }
        }
    }

    func sendTestNotification() {
        notificationTestStatus = nil
        notificationNeedsSettings = false
        Task {
            let result = await sendTestNotificationInternal()
            await MainActor.run {
                self.notificationTestStatus = result.message
                self.notificationNeedsSettings = result.needsSettings
            }
        }
    }

    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    private struct NotificationTestResult {
        let message: String
        let needsSettings: Bool
    }

    private func sendTestNotificationInternal() async -> NotificationTestResult {
        guard Bundle.main.bundlePath.hasSuffix(".app") else {
            return NotificationTestResult(
                message: "Notifications require running from the .app bundle, not swift run.",
                needsSettings: false
            )
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            if !granted {
                return NotificationTestResult(
                    message: "Permission denied. Tap below to open System Settings and enable ResetStat.",
                    needsSettings: true
                )
            }
        } else if settings.authorizationStatus == .denied {
            return NotificationTestResult(
                message: "Notifications are blocked. Tap below to open System Settings and enable ResetStat.",
                needsSettings: true
            )
        }

        await notificationCoordinator.sendTestNotification()
        return NotificationTestResult(
            message: "Test notification sent. Check Notification Center if no banner appears.",
            needsSettings: false
        )
    }

    private func requestNotificationAuthorization() async {
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    func refreshProvider(_ tab: ProviderTab) async {
        guard isProviderEnabled(tab) else { return }
        guard !refreshingProviders.contains(tab) else { return }
        isRefreshing = true
        defer { updateIsRefreshing() }
        switch tab {
        case .codex:
            await refreshCodex()
        case .cursor:
            await refreshCursor()
        case .devin:
            await refreshDesktopQuotas()
        case .openCodeGo:
            await refreshOpenCodeGo()
        case .overview, .settings:
            return
        }
    }

    private func updateIsRefreshing() {
        isRefreshing = !refreshingProviders.isEmpty
    }

    func updateConfiguration(_ update: (inout ResetStatConfiguration) -> Void) {
        update(&configuration)
        configurationStore?.configuration = configuration
        configurationStore?.save()
        applyDisabledStates()
    }

    func resetConfigurationToDefaults() {
        configuration = .defaults
        configurationStore?.configuration = configuration
        configurationStore?.save()
        applyDisabledStates()
    }

    private func refreshCodex() async {
        refreshingProviders.insert(.codex)
        updateIsRefreshing()
        defer {
            refreshingProviders.remove(.codex)
            updateIsRefreshing()
        }
        state = snapshot == nil ? .loading : .loaded
        do {
            snapshot = try await withRetry { try await codexService().fetchSnapshot() }
            state = .loaded
            lastFetchAt[.codex] = Date()
            updatePaceProjection(for: .codex)
        } catch let error as CodexUsageError {
            state = .failed(error.localizedDescription)
        } catch {
            state = .failed("Usage data is temporarily unavailable.")
        }
    }

    private func refreshCursor() async {
        refreshingProviders.insert(.cursor)
        updateIsRefreshing()
        defer {
            refreshingProviders.remove(.cursor)
            updateIsRefreshing()
        }
        cursorState = cursorSnapshot == nil ? .loading : .loaded
        do {
            cursorSnapshot = try await withRetry { try await cursorUsageService().fetchSnapshot() }
            cursorState = .loaded
            lastFetchAt[.cursor] = Date()
            updatePaceProjection(for: .cursor)
        } catch let error as CursorUsageError {
            cursorState = .failed(error.localizedDescription)
        } catch {
            cursorState = .failed("Cursor usage is temporarily unavailable.")
        }
    }

    private func refreshDesktopQuotas() async {
        refreshingProviders.insert(.devin)
        updateIsRefreshing()
        defer {
            refreshingProviders.remove(.devin)
            updateIsRefreshing()
        }
        desktopQuotaState = desktopQuotaSnapshots.isEmpty ? .loading : .loaded
        do {
            let snapshots = try await withRetry { try await desktopQuotaUsageService().fetchSnapshots() }
            desktopQuotaSnapshots = snapshots
            desktopQuotaState = snapshots.isEmpty ? .failed("Devin quota cache unavailable.") : .loaded
            lastFetchAt[.devin] = Date()
            if !snapshots.isEmpty {
                updatePaceProjection(for: .devin)
            }
        } catch {
            desktopQuotaState = .failed("Devin quotas are temporarily unavailable.")
        }
    }

    private func refreshOpenCodeGo() async {
        refreshingProviders.insert(.openCodeGo)
        updateIsRefreshing()
        defer {
            refreshingProviders.remove(.openCodeGo)
            updateIsRefreshing()
        }
        openCodeGoState = openCodeGoSnapshot == nil ? .loading : .loaded
        do {
            openCodeGoSnapshot = try await withRetry { try await openCodeGoUsageService().fetchSnapshot() }
            openCodeGoState = .loaded
            lastFetchAt[.openCodeGo] = Date()
            updatePaceProjection(for: .openCodeGo)
        } catch let error as CodexUsageError {
            openCodeGoState = .failed(error.localizedDescription)
        } catch {
            openCodeGoState = .failed("OpenCode Go usage is temporarily unavailable.")
        }
    }

    private func withRetry<T>(_ operation: () async throws -> T) async throws -> T {
        guard configuration.refresh.retryEnabled else { return try await operation() }
        let maxAttempts = configuration.refresh.maxRetryAttempts
        var attempt = 0
        while true {
            do {
                return try await operation()
            } catch {
                attempt += 1
                if attempt >= maxAttempts { throw error }
                let delaySeconds = retryDelayProvider(attempt)
                if delaySeconds > 0 {
                    try? await Task.sleep(for: .seconds(delaySeconds))
                }
            }
        }
    }

    var retryDelayProvider: (Int) -> TimeInterval = { attempt in
        pow(2.0, Double(attempt)) * 2
    }

    private func codexService() -> CodexUsageFetching {
        service ?? CodexAppServerClient(executablePath: configuration.providers.codex.executablePath)
    }

    private func cursorUsageService() -> CursorUsageFetching {
        cursorService ?? CursorUsageClient(stateDatabasePath: configuration.providers.cursor.stateDatabasePath)
    }

    private func desktopQuotaUsageService() -> DesktopQuotaFetching {
        if let desktopQuotaService {
            return desktopQuotaService
        }
        let source = DesktopQuotaSource(
            appName: "Devin Desktop",
            databasePath: configuration.providers.devin.stateDatabasePath,
            keyQueries: [
                "SELECT value FROM ItemTable WHERE key='windsurfAuthStatus' LIMIT 1;",
                "SELECT value FROM ItemTable WHERE key LIKE 'windsurf.reactSettings.cachedPlanInfoData:%' ORDER BY key LIMIT 1;",
                "SELECT value FROM ItemTable WHERE key='windsurf.settings.cachedPlanInfo' LIMIT 1;"
            ]
        )
        return DesktopQuotaClient(sources: [source], liveDatabasePath: configuration.providers.devin.stateDatabasePath)
    }

    private func openCodeGoUsageService() -> OpenCodeGoUsageFetching {
        openCodeGoService ?? OpenCodeGoUsageClient(configPath: configuration.providers.openCodeGo.configPath)
    }

    func isProviderEnabled(_ tab: ProviderTab) -> Bool {
        switch tab {
        case .codex:
            return configuration.providers.codex.isEnabled
        case .cursor:
            return configuration.providers.cursor.isEnabled
        case .devin:
            return configuration.providers.devin.isEnabled
        case .openCodeGo:
            return configuration.providers.openCodeGo.isEnabled
        case .overview, .settings:
            return true
        }
    }

    private func applyDisabledStates() {
        if !configuration.providers.codex.isEnabled {
            state = .disabled
            snapshot = nil
            paceProjections[.codex] = nil
            previousPaceSamples[.codex] = nil
        }
        if !configuration.providers.cursor.isEnabled {
            cursorState = .disabled
            cursorSnapshot = nil
            paceProjections[.cursor] = nil
            previousPaceSamples[.cursor] = nil
        }
        if !configuration.providers.devin.isEnabled {
            desktopQuotaState = .disabled
            desktopQuotaSnapshots = []
            paceProjections[.devin] = nil
            previousPaceSamples[.devin] = nil
        }
        if !configuration.providers.openCodeGo.isEnabled {
            openCodeGoState = .disabled
            openCodeGoSnapshot = nil
            paceProjections[.openCodeGo] = nil
            previousPaceSamples[.openCodeGo] = nil
        }
    }

    private func updatePaceProjection(for tab: ProviderTab) {
        guard let summary = providerSummaries.first(where: { $0.tab == tab }),
              let percent = summary.percentUsed else {
            previousPaceSamples[tab] = nil
            paceProjections[tab] = nil
            return
        }

        let now = Date()
        if let previous = previousPaceSamples[tab] {
            let projection = UsagePaceProjection.project(
                currentPercent: percent,
                previousPercent: previous.percentUsed,
                previousTimestamp: previous.timestamp,
                now: now,
                resetAt: summary.resetAt
            )
            paceProjections[tab] = projection
        }
        previousPaceSamples[tab] = PaceSample(percentUsed: percent, timestamp: now)
    }

    private func refreshLoop() async {
        while !Task.isCancelled {
            refreshTask = Task { await refresh() }
            await refreshTask?.value
            let interval = configuration.refresh.intervalSeconds
            try? await Task.sleep(for: .seconds(interval))
        }
    }

    private func clockLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            now = Date()
        }
    }
}
