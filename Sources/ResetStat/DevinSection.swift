import AppKit
import ResetStatCore
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

    var body: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
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
                }

                if !snapshots.isEmpty {
                    VStack(spacing: 12) {
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
        VStack(alignment: .leading, spacing: 9) {
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

            if quota.overageBalanceMicros != nil || quota.cycleEnd != nil {
                Divider()

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Extra usage balance")
                            .font(.caption.weight(.semibold))
                        if let cycleEnd = quota.cycleEnd {
                            Text("Plan ends \(UsageFormatting.resetText(date: cycleEnd, now: now))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(UsageFormatting.usd(micros: quota.overageBalanceMicros))
                        .font(.caption.weight(.semibold))
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
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(resetAt.map { UsageFormatting.timeRemainingText(date: $0, now: now) } ?? "Unknown")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(resetAt == nil ? .secondary : .primary)
            }

            ProgressView(value: Double(displayedPercent ?? 0), total: 100)
                .tint(tint)

            HStack {
                Text(displayedPercent.map { "\($0)% used" } ?? "Usage not reported")
                Spacer()
                Text("Resets \(quotaResetText(resetAt, now: now))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}
