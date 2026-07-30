import AppKit
import LimitLensCore
import SwiftUI

struct CodexSectionView: View {
    let snapshot: LimitLensSnapshot
    let now: Date
    let hidesProviderNames: Bool
    var isRefreshing: Bool = false
    var lastUpdated: Date? = nil
    var onRefresh: (() -> Void)? = nil
    var paceProjection: PaceProjection? = nil
    var isCollectingPaceData: Bool = false
    var paceChart: QuotaPaceChartData? = nil
    @State private var showsResetCreditDetails = false
    @State private var showsLocalUsageInfo = false

    var body: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 9) {
                SectionHeader(
                    title: providerName("Codex", privateName: "Provider 1", hidesProviderNames: hidesProviderNames),
                    detail: codexHeaderDetail,
                    systemImage: "terminal",
                    hidesProviderNames: hidesProviderNames,
                    dashboardURL: ProviderTab.codex.dashboardURL,
                    isRefreshing: isRefreshing,
                    lastUpdated: lastUpdated,
                    onRefresh: onRefresh
                )

                if let paceProjection {
                    PaceProjectionLine(projection: paceProjection)
                } else if isCollectingPaceData {
                    PaceCollectingLine()
                }

                HStack(alignment: .top, spacing: 8) {
                    resetWindowView(title: "Primary", window: snapshot.rateLimit.primary, tint: .blue)
                    if let secondary = snapshot.rateLimit.secondary {
                        resetWindowView(title: "Secondary", window: secondary, tint: .cyan)
                    }
                }

                if let paceChart {
                    Divider()
                    QuotaPaceChart(data: paceChart, tint: .blue)
                }

                Divider()

                resetCreditsView(snapshot.resetCredits)

                if let localUsage = snapshot.localUsage {
                    localUsageView(localUsage)
                    Divider()
                }

                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                    MetricTile(
                        title: "Lifetime tokens",
                        value: UsageFormatting.compactNumber(snapshot.tokenUsage?.lifetimeTokens)
                    )
                    MetricTile(
                        title: "Peak daily",
                        value: UsageFormatting.compactNumber(snapshot.tokenUsage?.peakDailyTokens)
                    )
                    MetricTile(
                        title: "Current streak",
                        value: streakText(snapshot.tokenUsage?.currentStreakDays)
                    )
                }

                if !snapshot.dailyUsageBuckets.isEmpty {
                    Divider()
                    DailyUsageChart(buckets: snapshot.dailyUsageBuckets)
                }
            }
        }
    }

    private var codexHeaderDetail: String? {
        let plan = UsageFormatting.planTitle(snapshot.rateLimit.planType)
        guard let billingDate = snapshot.planExpiresAt else {
            return "\(plan) · Renewal unavailable"
        }
        return "\(plan) · Renews \(UsageFormatting.resetText(date: billingDate, now: now))"
    }

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    private func localUsageView(_ usage: CodexLocalUsageSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Text("Local token usage & API equivalent")
                    .font(.caption2.weight(.semibold))
                Button {
                    showsLocalUsageInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(CompactHitTargetButtonStyle())
                .help("About local usage and API-equivalent cost")
                .popover(isPresented: $showsLocalUsageInfo, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("About this estimate")
                            .font(.caption.weight(.semibold))
                        Text(
                            "Calculated from local Codex session logs using each model's public API token prices. "
                                + "It is an API-equivalent value, not an additional subscription charge."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(width: 280, alignment: .leading)
                }
                Spacer()
            }

            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 8) {
                localUsageTile(title: "Last 24 hours", period: usage.last24Hours)
                localUsageTile(title: "Last 7 days", period: usage.last7Days)
                localUsageTile(title: "Last 30 days", period: usage.last30Days)
            }
        }
    }

    private func localUsageTile(title: String, period: CodexLocalUsagePeriod) -> some View {
        MetricTile(
            title: title,
            value: UsageFormatting.abbreviatedNumber(period.totalTokens),
            caption: localCostCaption(period),
            captionColor: period.hasCompleteCostEstimate ? .secondary : .orange
        )
    }

    private func localCostCaption(_ period: CodexLocalUsagePeriod) -> String {
        guard period.hasAnyCostEstimate else {
            return "API estimate unavailable"
        }
        let prefix = period.hasCompleteCostEstimate ? "≈" : "≥"
        let suffix = period.hasCompleteCostEstimate ? " API equivalent" : " priced portion"
        return prefix + UsageFormatting.usd(period.estimatedCostUSD) + suffix
    }

    private func resetWindowView(title: String, window: RateLimitWindow?, tint: Color) -> some View {
        UsageCard(
            label: title,
            percentUsed: window.map { Double($0.usedPercent) },
            leadingDetail: "Resets \(UsageFormatting.resetText(timestamp: window?.resetsAt, now: now))",
            trailingDetail: nil,
            tint: tint
        )
    }

    private func resetCreditsView(_ credits: ResetCreditInfo) -> some View {
        let expiry = resetCreditExpiry(credits)
        let expiringCredits = sortedExpiringCredits(credits)
        let canExpand = !expiringCredits.isEmpty

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Reset credits")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(resetCreditAvailabilityText(credits))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(credits.availableCount)")
                    .font(.callout.weight(.semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(expiry.text)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(expiry.color)
                        .lineLimit(1)
                    Text(expiry.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    showsResetCreditDetails.toggle()
                } label: {
                    HStack(spacing: 4) {
                        if canExpand {
                            Image(systemName: showsResetCreditDetails ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(CompactHitTargetButtonStyle())
                .disabled(!canExpand)
                .help(canExpand ? "Show all reset credit expiries" : "No additional reset credits")
            }

            if showsResetCreditDetails, canExpand {
                VStack(spacing: 7) {
                    ForEach(Array(expiringCredits.enumerated()), id: \.offset) { index, credit in
                        resetCreditDetailRow(index: index, credit: credit)
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resetCreditExpiry(_ credits: ResetCreditInfo) -> (text: String, detail: String, color: Color) {
        guard credits.availableCount > 0 else {
            return ("None available", "No reset credits to spend", .secondary)
        }
        guard let expiresAt = credits.nextExpiringCredit?.expiresAt else {
            return ("Expiry not reported", "Credit dates unavailable", .secondary)
        }

        let text = "Expires \(UsageFormatting.relativeDayText(date: expiresAt, now: now))"
        let detail = UsageFormatting.resetText(date: expiresAt, now: now)
        switch UsageFormatting.expiryUrgency(expiresAt: expiresAt, now: now) {
        case .expired, .soon:
            return (text, detail, .red)
        case .warning:
            return (text, detail, .yellow)
        case .healthy:
            return (text, detail, .green)
        case .unknown:
            return (text, detail, .secondary)
        }
    }

    private func resetCreditAvailabilityText(_ credits: ResetCreditInfo) -> String {
        guard let total = credits.totalEarnedCount, total >= credits.availableCount, total > 0 else {
            return credits.availableCount == 1 ? "1 available" : "\(credits.availableCount) available"
        }
        return "\(credits.availableCount) of \(total) available"
    }

    private func resetCreditDetailRow(index: Int, credit: ResetCredit) -> some View {
        let expiry = resetCreditExpiry(date: credit.expiresAt)

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(credit.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Credit \(index + 1)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(resetCreditSubtitle(credit))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(expiry.text)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(expiry.color)
                    .lineLimit(1)
                Text(expiry.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func resetCreditExpiry(date: Date?) -> (text: String, detail: String, color: Color) {
        guard let date else {
            return ("Expiry unknown", "Date unavailable", .secondary)
        }

        let text = UsageFormatting.relativeDayText(date: date, now: now)
        let detail = UsageFormatting.resetText(date: date, now: now)
        switch UsageFormatting.expiryUrgency(expiresAt: date, now: now) {
        case .expired, .soon:
            return (text, detail, .red)
        case .warning:
            return (text, detail, .yellow)
        case .healthy:
            return (text, detail, .green)
        case .unknown:
            return (text, detail, .secondary)
        }
    }

    private func resetCreditSubtitle(_ credit: ResetCredit) -> String {
        [credit.resetType, credit.status]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
            .joined(separator: " · ")
            .nilIfEmpty ?? "Reset credit"
    }

    private func sortedExpiringCredits(_ credits: ResetCreditInfo) -> [ResetCredit] {
        credits.credits
            .filter { $0.expiresAt != nil }
            .sorted { ($0.expiresAt ?? .distantFuture) < ($1.expiresAt ?? .distantFuture) }
    }
}
