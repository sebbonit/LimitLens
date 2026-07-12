import AppKit
import LimitLensCore
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
    var isCollectingPaceData: Bool = false

    var body: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 9) {
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
                } else if isCollectingPaceData {
                    PaceCollectingLine()
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
        VStack(alignment: .leading, spacing: 8) {
            if let rolling = snapshot.rolling {
                openCodeGoUsageBar(title: "Rolling", window: rolling, tint: .mint)
            }
            if let weekly = snapshot.weekly {
                openCodeGoUsageBar(title: "Weekly", window: weekly, tint: .orange)
            }
            if let monthly = snapshot.monthly {
                openCodeGoUsageBar(title: "Monthly", window: monthly, tint: .blue)
            }
        }
    }

    private func openCodeGoUsageBar(title: String, window: OpenCodeGoUsageWindow, tint: Color) -> some View {
        UsageCard(
            label: title,
            percentUsed: window.usedPercent,
            leadingDetail: window.resetAt.map { "Resets \(quotaResetText($0, now: now))" },
            trailingDetail: nil,
            tint: tint
        )
    }
}
