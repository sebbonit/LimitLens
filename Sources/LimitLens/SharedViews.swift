import AppKit
import LimitLensCore
import SwiftUI

private struct AppAppearanceKey: EnvironmentKey {
    static let defaultValue: AppAppearance = .classic
}

extension EnvironmentValues {
    var appAppearance: AppAppearance {
        get { self[AppAppearanceKey.self] }
        set { self[AppAppearanceKey.self] = newValue }
    }
}

extension AppAppearance {
    var popoverWidth: CGFloat {
        switch self {
        case .classic: return 460
        case .studio: return 680
        case .terminal: return 620
        }
    }

    var outerPadding: CGFloat {
        switch self {
        case .classic: return 12
        case .studio: return 16
        case .terminal: return 8
        }
    }

    var panelCornerRadius: CGFloat {
        switch self {
        case .classic: return 7
        case .studio: return 15
        case .terminal: return 2
        }
    }

    var cardCornerRadius: CGFloat {
        switch self {
        case .classic: return 8
        case .studio: return 12
        case .terminal: return 1
        }
    }

    var accentColor: Color {
        switch self {
        case .classic: return .accentColor
        case .studio: return .indigo
        case .terminal: return .green
        }
    }

    var preferredColorScheme: ColorScheme? {
        self == .terminal ? .dark : nil
    }

    func windowBackground(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .classic:
            return Color(nsColor: .windowBackgroundColor)
        case .studio:
            switch colorScheme {
            case .dark:
                return Color(red: 0.09, green: 0.095, blue: 0.14)
            default:
                return Color(red: 0.945, green: 0.95, blue: 0.975)
            }
        case .terminal:
            return Color(red: 0.025, green: 0.032, blue: 0.028)
        }
    }

    func panelBackground(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .classic:
            return Color(nsColor: .controlBackgroundColor)
        case .studio:
            switch colorScheme {
            case .dark:
                return Color(red: 0.12, green: 0.125, blue: 0.18)
            default:
                return .white
            }
        case .terminal:
            return Color(red: 0.035, green: 0.055, blue: 0.043)
        }
    }

    func cardBackground(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .studio:
            switch colorScheme {
            case .dark:
                return Color(red: 0.15, green: 0.155, blue: 0.22)
            default:
                return .white
            }
        default:
            return panelBackground(for: colorScheme)
        }
    }

    func studioShadowColor(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color.black.opacity(0.28)
        default:
            return Color.indigo.opacity(0.08)
        }
    }
}

struct SectionBlock<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.appAppearance) private var appearance
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content
            .padding(appearance == .terminal ? 8 : 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: appearance.panelCornerRadius, style: .continuous)
                    .fill(appearance.panelBackground(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: appearance.panelCornerRadius, style: .continuous)
                    .stroke(
                        appearance == .terminal ? Color.green.opacity(0.26) : appearance.accentColor.opacity(0.10),
                        lineWidth: appearance == .terminal ? 1 : 0.5
                    )
            )
            .shadow(
                color: appearance == .studio ? appearance.studioShadowColor(for: colorScheme) : .clear,
                radius: appearance == .studio ? 8 : 0,
                y: appearance == .studio ? 3 : 0
            )
    }
}

extension NSScroller {
    static func forceOverlayScrollers() {
        // Force overlay scrollers for this process so they stay visible
        // instead of auto-hiding based on the user's system preference.
        UserDefaults.standard.set(false, forKey: "AppleShowScrollBars")
        UserDefaults.standard.synchronize()
    }
}

struct DailyUsageChart: View {
    let buckets: [AccountTokenUsageDailyBucket]

    private static let isoDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let tooltipDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var displayedBuckets: [AccountTokenUsageDailyBucket] {
        Array(buckets.sorted { $0.startDate < $1.startDate }.suffix(14))
    }

    private var maxTokens: Int64 {
        max(displayedBuckets.map(\.tokens).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent Codex tokens")
                    .font(.caption2.weight(.semibold))
                Spacer()
                Text("\(displayedBuckets.count)d")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(displayedBuckets.enumerated()), id: \.offset) { _, bucket in
                    Button {
                    } label: {
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color.accentColor.opacity(0.78))
                                .frame(maxWidth: .infinity)
                                .frame(height: barHeight(for: bucket.tokens))
                            Text(dayLabel(bucket.startDate))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .bottom)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(tooltipText(for: bucket))
                }
            }
            .frame(height: 62)
        }
    }

    private func barHeight(for tokens: Int64) -> CGFloat {
        let ratio = CGFloat(Double(tokens) / Double(maxTokens))
        return max(4, ratio * 42)
    }

    private func dayLabel(_ startDate: String) -> String {
        guard let day = startDate.split(separator: "-").last else { return startDate }
        return String(day)
    }

    private func tooltipText(for bucket: AccountTokenUsageDailyBucket) -> String {
        let count = UsageFormatting.compactNumber(bucket.tokens)
        guard let date = Self.isoDayFormatter.date(from: bucket.startDate) else {
            return "\(count) tokens"
        }
        return "\(Self.tooltipDayFormatter.string(from: date)) · \(count) tokens"
    }
}

struct UsageCard: View {
    let label: String
    let percentUsed: Double?
    let leadingDetail: String?
    let trailingDetail: String?
    let tint: Color
    @Environment(\.appAppearance) private var appearance

    private var clampedPercent: Double {
        min(max(percentUsed ?? 0, 0), 100)
    }

    @ViewBuilder
    var body: some View {
        switch appearance {
        case .classic:
            classicCard
        case .studio:
            studioCard
        case .terminal:
            terminalCard
        }
    }

    private var classicCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(percentText(percentUsed))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(percentUsed == nil ? .secondary : .primary)
            }

            ProgressView(value: clampedPercent, total: 100)
                .controlSize(.small)
                .tint(tint)

            if leadingDetail != nil || trailingDetail != nil {
                HStack(spacing: 6) {
                    if let leadingDetail {
                        Text(leadingDetail)
                            .layoutPriority(1)
                    }
                    Spacer(minLength: 4)
                    if let trailingDetail {
                        Text(trailingDetail)
                            .layoutPriority(1)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 9)
        .padding(.top, 9)
        .padding(.bottom, 12)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
        )
    }

    private var studioCard: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.12), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: clampedPercent / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(percentText(percentUsed))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(tint)
                if let leadingDetail {
                    Text(leadingDetail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                if let trailingDetail {
                    Text(trailingDetail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
    }

    private var terminalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("[\(label.uppercased())]")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.green)
                Spacer()
                Text(percentText(percentUsed))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.72, green: 1, blue: 0.76))
            }

            HStack(spacing: 3) {
                ForEach(0..<12, id: \.self) { index in
                    Rectangle()
                        .fill(Double(index) < clampedPercent / (100.0 / 12.0) ? Color.green : Color.green.opacity(0.14))
                        .frame(height: 7)
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Text(leadingDetail ?? "NO RESET DATA")
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let trailingDetail {
                    Text(trailingDetail)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Color(red: 0.60, green: 0.74, blue: 0.63))
            .lineLimit(2)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(Color.black.opacity(0.26))
        .overlay(Rectangle().stroke(Color.green.opacity(0.32), lineWidth: 1))
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    var caption: String?
    var captionColor: Color = .secondary
    @Environment(\.appAppearance) private var appearance

    @ViewBuilder
    var body: some View {
        switch appearance {
        case .classic:
            metricContent
        case .studio:
            metricContent
                .padding(11)
                .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
                .background(Color.indigo.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
        case .terminal:
            metricContent
                .padding(9)
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
                .foregroundStyle(Color(red: 0.76, green: 1, blue: 0.79))
                .background(Color.black.opacity(0.22))
                .overlay(Rectangle().stroke(Color.green.opacity(0.22), lineWidth: 1))
        }
    }

    private var metricContent: some View {
        VStack(alignment: .leading, spacing: appearance == .studio ? 5 : 3) {
            Text(title)
                .font(appearance == .terminal ? .system(size: 9, weight: .bold, design: .monospaced) : .caption2.weight(.medium))
                .foregroundStyle(appearance == .terminal ? Color.green.opacity(0.62) : Color.secondary)
            Text(value)
                .font(appearance == .studio ? .title3.weight(.bold) : .body.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(captionColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct StatusLine: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 14)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PaceProjectionLine: View {
    let projection: PaceProjection

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: projection.willExhaustBeforeReset ? "exclamationmark.triangle" : "checkmark.circle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(projection.willExhaustBeforeReset ? .orange : .secondary)
            Text(projection.summaryText)
                .font(.caption2)
                .foregroundStyle(projection.willExhaustBeforeReset ? .orange : .secondary)
        }
    }
}

struct PaceCollectingLine: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Collecting pace data...")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

enum LimitLensArtwork {
    static let image: NSImage = {
        let bundledURL = Bundle.main.url(forResource: "LimitLens", withExtension: "icns")
        let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/LimitLens.icns")

        return bundledURL.flatMap(NSImage.init(contentsOf:))
            ?? NSImage(contentsOf: sourceURL)
            ?? NSImage(size: NSSize(width: 512, height: 512))
    }()
}

struct LimitLensMark: View {
    var body: some View {
        Image(nsImage: LimitLensArtwork.image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

// MARK: - Shared popover helpers

func providerName(_ name: String, privateName: String, hidesProviderNames: Bool) -> String {
    hidesProviderNames ? privateName : name
}

func providerSafeMessage(_ message: String, hidesProviderNames: Bool) -> String {
    guard hidesProviderNames else { return message }
    return message
        .replacingOccurrences(of: "Codex", with: "Provider")
        .replacingOccurrences(of: "Cursor", with: "Provider")
        .replacingOccurrences(of: "Devin", with: "Provider")
        .replacingOccurrences(of: "OpenCode Go", with: "Provider")
        .replacingOccurrences(of: "OpenCode", with: "Provider")
}

func providerIcon(_ systemImage: String, hidesProviderNames: Bool) -> String {
    hidesProviderNames ? "circle.grid.2x2" : systemImage
}

func providerShortName(_ tab: ProviderTab, hidesProviderNames: Bool) -> String {
    if hidesProviderNames {
        switch tab {
        case .codex: return "P1"
        case .cursor: return "P2"
        case .devin: return "P3"
        case .openCodeGo: return "P4"
        default: return tab.privateName
        }
    }
    switch tab {
    case .codex: return "Codex"
    case .cursor: return "Cursor"
    case .devin: return "Devin"
    case .openCodeGo: return "Go"
    default: return tab.displayName
    }
}

func severityColor(_ severity: UsageSeverity) -> Color {
    switch severity {
    case .critical: return .red
    case .warning: return .orange
    case .healthy: return .green
    case .unavailable: return .secondary
    }
}

func expiryColor(_ urgency: UsageFormatting.ExpiryUrgency) -> Color {
    switch urgency {
    case .expired: return .red
    case .soon: return .orange
    case .warning: return .yellow
    case .healthy: return .green
    case .unknown: return .secondary
    }
}

func percentText(_ value: Double?) -> String {
    guard let value else { return "--" }
    return "\(Int(value.rounded()))%"
}

func streakText(_ days: Int64?) -> String {
    guard let days else { return "--" }
    return days == 1 ? "1 day" : "\(days) days"
}

func quotaPercentText(_ remainingPercent: Int?) -> String {
    guard let remainingPercent else { return "-- remaining" }
    return "\(remainingPercent)% remaining"
}

func cursorResetText(_ date: Date?, now: Date) -> String {
    guard let date else { return "unknown" }
    return UsageFormatting.resetText(date: date, now: now)
}

func quotaResetText(_ date: Date?, now: Date) -> String {
    guard let date else { return "unknown" }
    return UsageFormatting.resetText(date: date, now: now)
}

func advancedResetDate(_ date: Date?, interval: TimeInterval, now: Date) -> Date? {
    guard var date else { return nil }
    while date < now {
        date = date.addingTimeInterval(interval)
    }
    return date
}

struct SectionHeader: View {
    let title: String
    let detail: String?
    let systemImage: String
    let hidesProviderNames: Bool
    var dashboardURL: URL? = nil
    var isRefreshing: Bool = false
    var lastUpdated: Date? = nil
    var onRefresh: (() -> Void)? = nil
    @Environment(\.appAppearance) private var appearance

    @ViewBuilder
    var body: some View {
        switch appearance {
        case .classic:
            classicHeader
        case .studio:
            studioHeader
        case .terminal:
            terminalHeader
        }
    }

    private var classicHeader: some View {
        HStack(spacing: 7) {
            Image(systemName: providerIcon(systemImage, hidesProviderNames: hidesProviderNames))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(title)
                .font(.subheadline.weight(.semibold))

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            headerControls
        }
    }

    private var studioHeader: some View {
        HStack(spacing: 11) {
            Image(systemName: providerIcon(systemImage, hidesProviderNames: hidesProviderNames))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(appearance.accentColor)
                .frame(width: 34, height: 34)
                .background(appearance.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.title3.weight(.semibold))
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            headerControls
        }
        .padding(.bottom, 2)
    }

    private var terminalHeader: some View {
        HStack(spacing: 9) {
            Text("::")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(Color.green)
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.76, green: 1, blue: 0.79))
                if let detail, !detail.isEmpty {
                    Text(detail.uppercased())
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.green.opacity(0.62))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            headerControls
        }
        .padding(.bottom, 3)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.green.opacity(0.28)).frame(height: 1)
        }
    }

    @ViewBuilder
    private var headerControls: some View {
        if let lastUpdated {
            Text(lastUpdated.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(appearance == .terminal ? Color.green.opacity(0.65) : Color.secondary)
                .help("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
        }

        if let dashboardURL {
            Button {
                NSWorkspace.shared.open(dashboardURL)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(appearance == .terminal ? Color.green : Color.secondary)
            .help("Open dashboard")
        }

        if let onRefresh {
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(appearance == .terminal ? Color.green : Color.secondary)
            .disabled(isRefreshing)
            .help("Refresh")
        }
    }
}
