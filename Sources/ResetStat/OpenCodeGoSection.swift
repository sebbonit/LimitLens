import AppKit
import ResetStatCore
import SwiftUI

struct OpenCodeGoSectionView: View {
    let snapshot: OpenCodeGoUsageSnapshot?
    let state: UsageViewModel.LoadState
    let now: Date
    let hidesProviderNames: Bool
    var dashboardURL: URL? = nil
    var isRefreshing: Bool = false
    var lastUpdated: Date? = nil
    var onRefresh: (() -> Void)? = nil
    var paceProjection: PaceProjection? = nil

    var body: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: providerName("OpenCode Go", privateName: "Provider 4", hidesProviderNames: hidesProviderNames),
                    detail: headerDetail,
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    hidesProviderNames: hidesProviderNames,
                    dashboardURL: dashboardURL,
                    isRefreshing: isRefreshing,
                    lastUpdated: lastUpdated,
                    onRefresh: onRefresh
                )

                if let paceProjection {
                    PaceProjectionLine(projection: paceProjection)
                }

                if let snapshot = snapshot, snapshot.hasUsage {
                    openCodeGoUsageView(snapshot)
                } else if case .loading = state {
                    StatusLine(icon: "hourglass", color: .secondary, text: "Checking OpenCode Go usage...")
                } else if case .failed(let message) = state {
                    StatusLine(icon: "exclamationmark.circle", color: .orange, text: providerSafeMessage(message, hidesProviderNames: hidesProviderNames))
                } else {
                    StatusLine(icon: "minus.circle", color: .secondary, text: "OpenCode Go usage unavailable.")
                }
            }
        }
    }

    private var headerDetail: String? {
        snapshot?.source?.nilIfEmpty ?? "Go"
    }

    private func openCodeGoUsageView(_ snapshot: OpenCodeGoUsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            openCodeGoUsageBar(title: "Rolling", window: snapshot.rolling, tint: .mint)
            openCodeGoUsageBar(title: "Weekly", window: snapshot.weekly, tint: .orange)
            openCodeGoUsageBar(title: "Monthly", window: snapshot.monthly, tint: .blue)
        }
    }

    private func openCodeGoUsageBar(title: String, window: OpenCodeGoUsageWindow?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(UsageFormatting.timeRemainingText(date: window?.resetAt, now: now))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(window?.resetAt == nil ? .secondary : .primary)
            }

            ProgressView(value: window?.usedPercent ?? 0, total: 100)
                .tint(tint)

            HStack {
                Text(window.map { "\(Int($0.usedPercent.rounded()))% used" } ?? "Usage not reported")
                Spacer()
                Text("Resets \(quotaResetText(window?.resetAt, now: now))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}
