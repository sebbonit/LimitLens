import AppKit
import LimitLensCore
import SwiftUI

struct SectionBlock<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
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
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.accentColor.opacity(0.78))
                            .frame(height: barHeight(for: bucket.tokens))
                        Text(dayLabel(bucket.startDate))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .bottom)
                    .help("\(UsageFormatting.compactNumber(bucket.tokens)) tokens")
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
}

struct UsageMeter: View {
    let label: String
    let percentUsed: Double?
    let usageText: String
    let resetText: String
    let tint: Color

    private var clampedPercent: Double {
        min(max(percentUsed ?? 0, 0), 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(percentText(percentUsed))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(percentUsed == nil ? .secondary : .primary)
            }

            ProgressView(value: clampedPercent, total: 100)
                .controlSize(.small)
                .tint(tint)

            HStack {
                Text(usageText)
                Spacer()
                Text(resetText)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, 1)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    var caption: String?
    var captionColor: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
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

struct SMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.14, blue: 0.22),
                            Color(red: 0.04, green: 0.07, blue: 0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            ActivityRingsMark()
                .padding(5)
        }
        .frame(width: 28, height: 28)
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
}

struct ActivityRingsMark: View {
    var body: some View {
        ZStack {
            ring(color: Color(red: 0.24, green: 0.51, blue: 0.96), progress: 0.72, radius: 9)
            ring(color: Color(red: 0.30, green: 0.85, blue: 0.60), progress: 0.45, radius: 6.5)
            ring(color: Color(red: 0.96, green: 0.56, blue: 0.20), progress: 0.85, radius: 4)
            ring(color: Color(red: 0.69, green: 0.32, blue: 0.96), progress: 0.30, radius: 1.5)
        }
    }

    private func ring(color: Color, progress: CGFloat, radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 1.8)
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                .frame(width: radius * 2, height: radius * 2)
                .rotationEffect(.degrees(-90))
        }
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

    var body: some View {
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

            if let lastUpdated {
                Text(lastUpdated.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
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
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
                .disabled(isRefreshing)
                .help("Refresh")
            }
        }
    }
}

