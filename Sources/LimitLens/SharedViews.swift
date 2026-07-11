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
                            .font(.system(size: 9, weight: .medium))
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

struct UsageCard: View {
    let label: String
    let percentUsed: Double?
    let leadingDetail: String?
    let trailingDetail: String?
    let tint: Color

    private var clampedPercent: Double {
        min(max(percentUsed ?? 0, 0), 100)
    }

    var body: some View {
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
                    }
                    Spacer(minLength: 4)
                    if let trailingDetail {
                        Text(trailingDetail)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
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
}

struct MetricTile: View {
    let title: String
    let value: String
    var caption: String?
    var captionColor: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold))
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
