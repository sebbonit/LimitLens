import AppKit
import ResetStatCore
import SwiftUI

struct SectionBlock<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent Codex tokens")
                    .font(.caption.weight(.semibold))
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

struct MetricTile: View {
    let title: String
    let value: String
    var caption: String?
    var captionColor: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
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
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)
    }
}

struct StatusLine: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 16)
            Text(text)
                .font(.callout)
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

struct SMark: View {
    var body: some View {
        Text("S")
            .font(.system(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.11, blue: 0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color(red: 0.22, green: 0.38, blue: 0.58), lineWidth: 1)
            )
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: providerIcon(systemImage, hidesProviderNames: hidesProviderNames))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let onRefresh {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isRefreshing)
                    .help("Refresh")
                }
            }
            if let lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if let dashboardURL {
                Button {
                    NSWorkspace.shared.open(dashboardURL)
                } label: {
                    Label("Open", systemImage: "globe")
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .help("Open dashboard")
            }
        }
    }
}

