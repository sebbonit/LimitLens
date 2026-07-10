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
        VStack(alignment: .leading, spacing: 10) {
            UsageCard(
                label: "Plan usage",
                percentUsed: cursor.usedPercent,
                leadingDetail: cursor.remainingCents.map { "\(UsageFormatting.usd(cents: $0)) left" },
                trailingDetail: "Resets \(cursorResetText(cursor.billingCycleEnd, now: now))",
                tint: .purple
            )

            if cursor.autoPercentUsed != nil || cursor.apiPercentUsed != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Breakdown")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(alignment: .top, spacing: 8) {
                        if cursor.autoPercentUsed != nil {
                            cursorLimitView(
                                title: "Auto",
                                percentUsed: cursor.autoPercentUsed,
                                spendCents: cursor.autoSpendCents,
                                limitCents: cursor.autoLimitCents,
                                tint: .purple
                            )
                        }
                        if cursor.apiPercentUsed != nil {
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
        }
    }

    private func cursorLimitView(
        title: String,
        percentUsed: Double?,
        spendCents: Int?,
        limitCents: Int?,
        tint: Color
    ) -> some View {
        UsageCard(
            label: title,
            percentUsed: percentUsed,
            leadingDetail: spendCents.map { "\(UsageFormatting.usd(cents: $0)) used" },
            trailingDetail: limitCents.map { "Limit \(UsageFormatting.usd(cents: $0))" },
            tint: tint
        )
    }
}
