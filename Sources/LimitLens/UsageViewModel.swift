import AppKit
import Foundation
import LimitLensCore
import SwiftUI
@preconcurrency import UserNotifications

@MainActor
final class UsageViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
        case disabled
    }

    @Published private(set) var snapshot: LimitLensSnapshot?
    @Published private(set) var cursorSnapshot: CursorUsageSnapshot?
    @Published private(set) var desktopQuotaSnapshots: [DesktopQuotaSnapshot] = []
    @Published private(set) var openCodeGoSnapshot: OpenCodeGoUsageSnapshot?
    @Published private(set) var state: LoadState = .idle
    @Published private(set) var cursorState: LoadState = .idle
    @Published private(set) var desktopQuotaState: LoadState = .idle
    @Published private(set) var openCodeGoState: LoadState = .idle
    @Published private(set) var isRefreshing = false
    @Published private(set) var configuration: LimitLensConfiguration
    @Published private(set) var now = Date()
    private var lastClockMinute: Int = -1

    /// Test hook to override the current time.
    func setNowForTesting(_ date: Date) {
        now = date
        lastClockMinute = Calendar.current.component(.minute, from: date)
    }
    @Published private(set) var lastFetchAt: [ProviderTab: Date] = [:]
    @Published private(set) var paceProjections: [ProviderTab: PaceProjection] = [:]
    @Published private(set) var collectingPaceData: Set<ProviderTab> = []
    @Published private(set) var lastErrors: [ProviderTab: String] = [:]
    @Published private(set) var diagnosticTestResults: [ProviderTab: DiagnosticTestResult] = [:]
    @Published private(set) var autoSwitchDisplay: MenuBarDisplay = .logos
    @Published var exhaustionSummaries: [ExhaustionSpeedSummary] = []

    private var paceSampleHistory: [ProviderTab: [PaceSample]] = [:]

    var isProviderRefreshing: (ProviderTab) -> Bool {
        { self.refreshingProviders[$0] != nil }
    }

    private let configurationStore: LimitLensConfigurationStore?
    private let service: CodexUsageFetching?
    private let cursorService: CursorUsageFetching?
    private let desktopQuotaService: DesktopQuotaFetching?
    private let openCodeGoService: OpenCodeGoUsageFetching?
    internal let historyStore: QuotaExhaustionHistoryStoring
    private var didStartLoops = false
    private var refreshingProviders: [ProviderTab: UUID] = [:]
    private let notificationCoordinator: NotificationCoordinator
    private var scheduledRefreshTask: Task<Void, Never>?
    private var refreshLoopTask: Task<Void, Never>?
    private var refreshLoopGeneration: UUID?
    private var clockLoopTask: Task<Void, Never>?
    private var autoSwitchLoopTask: Task<Void, Never>?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var applicationActiveObserver: NSObjectProtocol?

    convenience init(configurationStore: LimitLensConfigurationStore = LimitLensConfigurationStore()) {
        self.init(
            configurationStore: configurationStore,
            configuration: configurationStore.configuration,
            service: nil,
            cursorService: nil,
            desktopQuotaService: nil,
            openCodeGoService: nil,
            notificationCoordinator: NotificationCoordinator(),
            historyStore: QuotaExhaustionHistoryStore()
        )
    }

    init(
        configuration: LimitLensConfiguration = .defaults,
        service: CodexUsageFetching,
        cursorService: CursorUsageFetching,
        desktopQuotaService: DesktopQuotaFetching,
        openCodeGoService: OpenCodeGoUsageFetching,
        notificationCoordinator: NotificationCoordinator = NotificationCoordinator(),
        historyStore: QuotaExhaustionHistoryStoring = QuotaExhaustionHistoryStore()
    ) {
        self.configurationStore = nil
        self.configuration = configuration
        self.service = service
        self.cursorService = cursorService
        self.desktopQuotaService = desktopQuotaService
        self.openCodeGoService = openCodeGoService
        self.notificationCoordinator = notificationCoordinator
        self.historyStore = historyStore
        updateExhaustionSummaries()
    }

    private init(
        configurationStore: LimitLensConfigurationStore?,
        configuration: LimitLensConfiguration,
        service: CodexUsageFetching?,
        cursorService: CursorUsageFetching?,
        desktopQuotaService: DesktopQuotaFetching?,
        openCodeGoService: OpenCodeGoUsageFetching?,
        notificationCoordinator: NotificationCoordinator,
        historyStore: QuotaExhaustionHistoryStoring
    ) {
        self.configurationStore = configurationStore
        self.configuration = configuration
        self.service = service
        self.cursorService = cursorService
        self.desktopQuotaService = desktopQuotaService
        self.openCodeGoService = openCodeGoService
        self.notificationCoordinator = notificationCoordinator
        self.historyStore = historyStore
        updateExhaustionSummaries()
    }

    func start() {
        if !didStartLoops {
            didStartLoops = true
            clockLoopTask = Task { await clockLoop() }
            autoSwitchLoopTask = Task { await autoSwitchLoop() }
            observeWorkspacePowerState()
        }

        startRefreshLoopIfNeeded()
    }

    private func startRefreshLoopIfNeeded() {
        guard refreshLoopTask == nil || refreshLoopTask?.isCancelled == true else { return }
        let generation = UUID()
        refreshLoopGeneration = generation
        refreshLoopTask = Task { await refreshLoop(generation: generation) }
    }

    /// System sleep can leave in-flight network and subprocess requests hung
    /// after the network drops. Cancel before sleep, then start a clean refresh
    /// on wake so the UI cannot remain pinned in its refreshing state.
    private func observeWorkspacePowerState() {
        let center = NSWorkspace.shared.notificationCenter
        sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleSystemSleep() }
        }
        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleSystemWake() }
        }

        applicationActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApplication.shared,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.startRefreshLoopIfNeeded() }
        }
    }

    private func handleSystemSleep() {
        scheduledRefreshTask?.cancel()
        refreshingProviders.removeAll()
        updateIsRefreshing()
    }

    private func handleSystemWake() {
        now = Date()
        scheduledRefreshTask?.cancel()
        refreshLoopTask?.cancel()
        refreshingProviders.removeAll()
        updateIsRefreshing()
        startRefreshLoopIfNeeded()
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
        guard !Task.isCancelled else { return }
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
                    message: "Permission denied. Tap below to open System Settings and enable LimitLens.",
                    needsSettings: true
                )
            }
        } else if settings.authorizationStatus == .denied {
            return NotificationTestResult(
                message: "Notifications are blocked. Tap below to open System Settings and enable LimitLens.",
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
        guard refreshingProviders[tab] == nil else { return }
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

    private func beginRefreshing(_ tab: ProviderTab) -> UUID {
        let refreshID = UUID()
        refreshingProviders[tab] = refreshID
        updateIsRefreshing()
        return refreshID
    }

    private func finishRefreshing(_ tab: ProviderTab, refreshID: UUID) {
        guard refreshingProviders[tab] == refreshID else { return }
        refreshingProviders[tab] = nil
        updateIsRefreshing()
    }

    func updateConfiguration(_ update: (inout LimitLensConfiguration) -> Void) {
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
        let refreshID = beginRefreshing(.codex)
        defer { finishRefreshing(.codex, refreshID: refreshID) }
        state = snapshot == nil ? .loading : .loaded
        do {
            let refreshedSnapshot = try await withRetry { try await codexService().fetchSnapshot() }
            try Task.checkCancellation()
            guard refreshingProviders[.codex] == refreshID else { return }
            snapshot = refreshedSnapshot
            state = .loaded
            lastFetchAt[.codex] = Date()
            updatePaceProjection(for: .codex)
            recordExhaustionIfNeeded(for: .codex)
            lastErrors[.codex] = nil
        } catch is CancellationError {
            return
        } catch let error as CodexUsageError {
            guard refreshingProviders[.codex] == refreshID else { return }
            state = .failed(error.localizedDescription)
            lastErrors[.codex] = error.localizedDescription
        } catch {
            guard refreshingProviders[.codex] == refreshID else { return }
            state = .failed("Usage data is temporarily unavailable.")
            lastErrors[.codex] = "Usage data is temporarily unavailable."
        }
    }

    private func refreshCursor() async {
        let refreshID = beginRefreshing(.cursor)
        defer { finishRefreshing(.cursor, refreshID: refreshID) }
        cursorState = cursorSnapshot == nil ? .loading : .loaded
        do {
            let refreshedSnapshot = try await withRetry { try await cursorUsageService().fetchSnapshot() }
            try Task.checkCancellation()
            guard refreshingProviders[.cursor] == refreshID else { return }
            cursorSnapshot = refreshedSnapshot
            cursorState = .loaded
            lastFetchAt[.cursor] = Date()
            updatePaceProjection(for: .cursor)
            recordExhaustionIfNeeded(for: .cursor)
            lastErrors[.cursor] = nil
        } catch is CancellationError {
            return
        } catch let error as CursorUsageError {
            guard refreshingProviders[.cursor] == refreshID else { return }
            cursorState = .failed(error.localizedDescription)
            lastErrors[.cursor] = error.localizedDescription
        } catch {
            guard refreshingProviders[.cursor] == refreshID else { return }
            cursorState = .failed("Cursor usage is temporarily unavailable.")
            lastErrors[.cursor] = "Cursor usage is temporarily unavailable."
        }
    }

    private func refreshDesktopQuotas() async {
        let refreshID = beginRefreshing(.devin)
        defer { finishRefreshing(.devin, refreshID: refreshID) }
        desktopQuotaState = desktopQuotaSnapshots.isEmpty ? .loading : .loaded
        do {
            let snapshots = try await withRetry { try await desktopQuotaUsageService().fetchSnapshots() }
            try Task.checkCancellation()
            guard refreshingProviders[.devin] == refreshID else { return }
            desktopQuotaSnapshots = snapshots
            desktopQuotaState = snapshots.isEmpty ? .failed("Devin quota cache unavailable.") : .loaded
            if !snapshots.isEmpty {
                lastFetchAt[.devin] = Date()
                updatePaceProjection(for: .devin)
                recordExhaustionIfNeeded(for: .devin)
                lastErrors[.devin] = nil
            } else {
                lastErrors[.devin] = "Devin quota cache unavailable."
            }
        } catch is CancellationError {
            return
        } catch {
            guard refreshingProviders[.devin] == refreshID else { return }
            desktopQuotaState = .failed("Devin quotas are temporarily unavailable.")
            lastErrors[.devin] = "Devin quotas are temporarily unavailable."
        }
    }

    private func refreshOpenCodeGo() async {
        let refreshID = beginRefreshing(.openCodeGo)
        defer { finishRefreshing(.openCodeGo, refreshID: refreshID) }
        openCodeGoState = openCodeGoSnapshot == nil ? .loading : .loaded
        do {
            let refreshedSnapshot = try await withRetry { try await openCodeGoUsageService().fetchSnapshot() }
            try Task.checkCancellation()
            guard refreshingProviders[.openCodeGo] == refreshID else { return }
            openCodeGoSnapshot = refreshedSnapshot
            openCodeGoState = .loaded
            lastFetchAt[.openCodeGo] = Date()
            updatePaceProjection(for: .openCodeGo)
            recordExhaustionIfNeeded(for: .openCodeGo)
            lastErrors[.openCodeGo] = nil
        } catch is CancellationError {
            return
        } catch let error as CodexUsageError {
            guard refreshingProviders[.openCodeGo] == refreshID else { return }
            openCodeGoState = .failed(error.localizedDescription)
            lastErrors[.openCodeGo] = error.localizedDescription
        } catch {
            guard refreshingProviders[.openCodeGo] == refreshID else { return }
            openCodeGoState = .failed("OpenCode Go usage is temporarily unavailable.")
            lastErrors[.openCodeGo] = "OpenCode Go usage is temporarily unavailable."
        }
    }

    private func withRetry<T: Sendable>(_ operation: () async throws -> T) async throws -> T {
        let maxAttempts = configuration.refresh.retryEnabled
            ? configuration.refresh.maxRetryAttempts
            : 1
        var attempt = 0
        while true {
            try Task.checkCancellation()
            do {
                let value = try await operation()
                try Task.checkCancellation()
                return value
            } catch {
                if error is CancellationError || Task.isCancelled {
                    throw CancellationError()
                }
                attempt += 1
                if attempt >= maxAttempts { throw error }
                let delaySeconds = retryDelayProvider(attempt)
                if delaySeconds > 0 {
                    try await Task.sleep(for: .seconds(delaySeconds))
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
            paceSampleHistory[.codex] = nil
            collectingPaceData.remove(.codex)
            lastErrors[.codex] = nil
        }
        if !configuration.providers.cursor.isEnabled {
            cursorState = .disabled
            cursorSnapshot = nil
            paceProjections[.cursor] = nil
            paceSampleHistory[.cursor] = nil
            collectingPaceData.remove(.cursor)
            lastErrors[.cursor] = nil
        }
        if !configuration.providers.devin.isEnabled {
            desktopQuotaState = .disabled
            desktopQuotaSnapshots = []
            paceProjections[.devin] = nil
            paceSampleHistory[.devin] = nil
            collectingPaceData.remove(.devin)
            lastErrors[.devin] = nil
        }
        if !configuration.providers.openCodeGo.isEnabled {
            openCodeGoState = .disabled
            openCodeGoSnapshot = nil
            paceProjections[.openCodeGo] = nil
            paceSampleHistory[.openCodeGo] = nil
            collectingPaceData.remove(.openCodeGo)
            lastErrors[.openCodeGo] = nil
        }
        updateExhaustionSummaries()
    }

    private func updatePaceProjection(for tab: ProviderTab) {
        guard let summary = providerSummaries.first(where: { $0.tab == tab }),
              let percent = summary.percentUsed else {
            paceSampleHistory[tab] = nil
            paceProjections[tab] = nil
            collectingPaceData.remove(tab)
            return
        }

        let now = Date()
        var history = paceSampleHistory[tab] ?? []
        history.append(PaceSample(percentUsed: percent, timestamp: now))
        if history.count > UsagePaceProjection.maxSampleHistory {
            history.removeFirst(history.count - UsagePaceProjection.maxSampleHistory)
        }
        paceSampleHistory[tab] = history

        let projection = UsagePaceProjection.project(
            samples: history,
            now: now,
            resetAt: summary.resetAt
        )
        if let projection {
            paceProjections[tab] = projection
            collectingPaceData.remove(tab)
        } else {
            // Not enough elapsed time or samples yet — keep collecting
            collectingPaceData.insert(tab)
        }
    }

    func testProviderConnection(_ tab: ProviderTab) {
        let start = Date()
        Task {
            await refreshProvider(tab)
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            let loadState = currentLoadState(for: tab)
            let result: DiagnosticTestResult
            switch loadState {
            case .loaded:
                result = DiagnosticTestResult(timestamp: Date(), succeeded: true, message: "Connected successfully", elapsedMillis: elapsed)
            case .failed(let message):
                result = DiagnosticTestResult(timestamp: Date(), succeeded: false, message: message, elapsedMillis: elapsed)
            case .disabled:
                result = DiagnosticTestResult(timestamp: Date(), succeeded: false, message: "Provider is disabled", elapsedMillis: elapsed)
            case .idle, .loading:
                result = DiagnosticTestResult(timestamp: Date(), succeeded: false, message: "Test did not complete", elapsedMillis: elapsed)
            }
            diagnosticTestResults[tab] = result
        }
    }

    func currentLoadState(for tab: ProviderTab) -> LoadState {
        switch tab {
        case .codex: return state
        case .cursor: return cursorState
        case .devin: return desktopQuotaState
        case .openCodeGo: return openCodeGoState
        case .overview, .settings: return .idle
        }
    }

    func providerPath(for tab: ProviderTab) -> String {
        switch tab {
        case .codex: return configuration.providers.codex.executablePath
        case .cursor: return configuration.providers.cursor.stateDatabasePath
        case .devin: return configuration.providers.devin.stateDatabasePath
        case .openCodeGo: return configuration.providers.openCodeGo.configPath
        case .overview, .settings: return ""
        }
    }

    func providerPathExists(for tab: ProviderTab) -> Bool {
        let path = providerPath(for: tab)
        guard !path.isEmpty else { return false }
        if tab == .codex {
            return FileManager.default.fileExists(atPath: path) && FileManager.default.isExecutableFile(atPath: path)
        }
        return FileManager.default.fileExists(atPath: path)
    }

    private func refreshLoop(generation: UUID) async {
        while !Task.isCancelled {
            let refreshTask = Task { await refresh() }
            guard refreshLoopGeneration == generation else {
                refreshTask.cancel()
                return
            }
            scheduledRefreshTask = refreshTask
            await refreshTask.value

            guard refreshLoopGeneration == generation else { return }
            scheduledRefreshTask = nil

            guard !Task.isCancelled else { return }

            do {
                let interval = configuration.refresh.intervalSeconds
                try await Task.sleep(for: .seconds(interval))
            } catch is CancellationError {
                return
            } catch {
                continue
            }
        }
    }

    private func clockLoop() async {
        while !Task.isCancelled {
            let current = Date()
            let minute = Calendar.current.component(.minute, from: current)
            if minute != lastClockMinute {
                lastClockMinute = minute
                now = current
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func autoSwitchLoop() async {
        while !Task.isCancelled {
            guard configuration.privacy.menuBarDisplay == .auto else {
                try? await Task.sleep(for: .seconds(1))
                continue
            }
            autoSwitchDisplay = (autoSwitchDisplay == .logos) ? .countdowns : .logos
            let interval = configuration.privacy.autoSwitchIntervalSeconds
            try? await Task.sleep(for: .seconds(interval))
        }
    }
}
