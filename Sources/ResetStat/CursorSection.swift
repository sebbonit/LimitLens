import AppKit
import ResetStatCore
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

    var body: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
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
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(cursor.usedPercent.rounded()))% used")
                        .font(.title3.weight(.semibold))
                    Text("Resets \(cursorResetText(cursor.billingCycleEnd, now: now))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(UsageFormatting.usd(cents: cursor.remainingCents))
                        .font(.callout.weight(.semibold))
                    Text("of \(UsageFormatting.usd(cents: cursor.limitCents)) left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: cursor.usedPercent, total: 100)
                .tint(.purple)

            if cursor.autoPercentUsed != nil || cursor.apiPercentUsed != nil {
                VStack(spacing: 9) {
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
                .padding(.top, 2)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(percentText(percentUsed))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            ProgressView(value: percentUsed ?? 0, total: 100)
                .tint(tint)

            if spendCents != nil || limitCents != nil {
                HStack {
                    Text("\(UsageFormatting.usd(cents: spendCents)) used")
                    Spacer()
                    Text("Limit \(UsageFormatting.usd(cents: limitCents))")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }
}
