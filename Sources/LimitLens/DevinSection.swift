import AppKit
import LimitLensCore
import SwiftUI

struct DevinSectionView: View {
    let snapshots: [DesktopQuotaSnapshot]
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
                    title: providerName("Devin", privateName: "Provider 3", hidesProviderNames: hidesProviderNames),
                    detail: headerDetail,
                    systemImage: "sparkles",
                    hidesProviderNames: hidesProviderNames,
                    dashboardURL: ProviderTab.devin.dashboardURL,
                    isRefreshing: isRefreshing,
                    lastUpdated: lastUpdated,
                    onRefresh: onRefresh
                )

                if let paceProjection {
                    PaceProjectionLine(projection: paceProjection)
                } else if isCollectingPaceData {
                    PaceCollectingLine()
                }

                if !snapshots.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(snapshots, id: \.appName) { quota in
                            desktopQuotaView(quota)
                        }
                    }
                } else if case .loading = state {
                    StatusLine(icon: "hourglass", color: .secondary, text: "Checking Devin quota...")
                } else if case .failed(let message) = state {
                    StatusLine(icon: "exclamationmark.circle", color: .orange, text: providerSafeMessage(message, hidesProviderNames: hidesProviderNames))
                } else {
                    StatusLine(icon: "minus.circle", color: .secondary, text: "Devin quota unavailable.")
                }
            }
        }
    }

    private var headerDetail: String? {
        snapshots.first?.planName?.nilIfEmpty
    }

    private func desktopQuotaView(_ quota: DesktopQuotaSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                quotaBar(
                    title: "Daily",
                    usedPercent: quota.dailyUsedPercent,
                    isUnavailable: quota.shouldTreatQuotaUsageAsUnavailable,
                    resetAt: advancedResetDate(quota.dailyResetAt, interval: 86_400, now: now),
                    tint: .green
                )
                quotaBar(
                    title: "Weekly",
                    usedPercent: quota.weeklyUsedPercent,
                    isUnavailable: quota.shouldTreatQuotaUsageAsUnavailable,
                    resetAt: advancedResetDate(quota.weeklyResetAt, interval: 7 * 86_400, now: now),
                    tint: .orange
                )
            }

            if quota.overageBalanceMicros != nil || quota.cycleEnd != nil {
                Divider()

                HStack(alignment: .firstTextBaseline) {
                    Text("EXTRA USAGE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(UsageFormatting.usd(micros: quota.overageBalanceMicros))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                    if let cycleEnd = quota.cycleEnd {
                        Text("· \(UsageFormatting.resetText(date: cycleEnd, now: now))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func quotaBar(
        title: String,
        usedPercent: Int?,
        isUnavailable: Bool,
        resetAt: Date?,
        tint: Color
    ) -> some View {
        let displayedPercent = isUnavailable ? nil : usedPercent
        return UsageCard(
            label: title,
            percentUsed: displayedPercent.map { Double($0) },
            leadingDetail: resetAt.map { "Resets \(quotaResetText($0, now: now))" },
            trailingDetail: nil,
            tint: tint
        )
    }
}
