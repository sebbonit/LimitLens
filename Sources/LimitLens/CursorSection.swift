import AppKit
import LimitLensCore
import SwiftUI

struct CursorSectionView: View {
    let snapshot: CursorUsageSnapshot?
    let state: UsageViewModel.LoadState
    let now: Date
    let hidesProviderNames: Bool
    var isRefreshing: Bool = false
    var lastUpdated: Date? = nil
    var onRefresh: (() -> Void)? = nil
    var paceProjection: PaceProjection? = nil
    var isCollectingPaceData: Bool = false

    var body: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 9) {
                SectionHeader(
                    title: providerName("Cursor", privateName: "Provider 2", hidesProviderNames: hidesProviderNames),
                    detail: headerDetail,
                    systemImage: "cursorarrow",
                    hidesProviderNames: hidesProviderNames,
                    dashboardURL: ProviderTab.cursor.dashboardURL,
                    isRefreshing: isRefreshing,
                    lastUpdated: lastUpdated,
                    onRefresh: onRefresh
                )

                if let paceProjection {
                    PaceProjectionLine(projection: paceProjection)
                } else if isCollectingPaceData {
                    PaceCollectingLine()
                }

                if let cursor = snapshot {
                    cursorUsageView(cursor)
                } else if case .loading = state {
                    StatusLine(icon: "hourglass", color: .secondary, text: "Loading provider usage...")
                } else if case .failed(let message) = state {
                    StatusLine(icon: "exclamationmark.circle", color: .orange, text: providerSafeMessage(message, hidesProviderNames: hidesProviderNames))
                } else {
                    StatusLine(icon: "minus.circle", color: .secondary, text: "Provider usage unavailable.")
                }
            }
        }
    }

    private var headerDetail: String? {
        if let plan = snapshot?.planName {
            return plan
        }
        if case .failed = state {
            return "Unavailable"
        }
        return nil
    }

    private func cursorUsageView(_ cursor: CursorUsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            UsageMeter(
                label: "Plan usage",
                percentUsed: cursor.usedPercent,
                usageText: "\(UsageFormatting.usd(cents: cursor.remainingCents)) left",
                resetText: "Resets \(cursorResetText(cursor.billingCycleEnd, now: now))",
                tint: .purple
            )

            if cursor.autoPercentUsed != nil || cursor.apiPercentUsed != nil {
                Divider()

                VStack(spacing: 6) {
                    cursorLimitView(
                        title: "Auto",
                        percentUsed: cursor.autoPercentUsed,
                        spendCents: cursor.autoSpendCents,
                        limitCents: cursor.autoLimitCents,
                        tint: .purple
                    )
                    cursorLimitView(
                        title: "API",
                        percentUsed: cursor.apiPercentUsed,
                        spendCents: cursor.apiSpendCents,
                        limitCents: cursor.apiLimitCents,
                        tint: .indigo
                    )
                }
            }
        }
    }

    private func cursorLimitView(
        title: String,
        percentUsed: Double?,
        spendCents: Int?,
        limitCents: Int?,
        tint: Color
    ) -> some View {
        UsageMeter(
            label: title,
            percentUsed: percentUsed,
            usageText: "\(UsageFormatting.usd(cents: spendCents)) used",
            resetText: "Limit \(UsageFormatting.usd(cents: limitCents))",
            tint: tint
        )
    }
}
