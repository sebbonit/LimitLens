import AppKit
import ResetStatCore
import SwiftUI

struct CodexSectionView: View {
    let snapshot: ResetStatSnapshot
    let now: Date
    let hidesProviderNames: Bool
    var isRefreshing: Bool = false
    var lastUpdated: Date? = nil
    var onRefresh: (() -> Void)? = nil
    var paceProjection: PaceProjection? = nil
    @State private var showsResetCreditDetails = false

    var body: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
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
                }

                VStack(spacing: 10) {
                    resetWindowView(title: "Primary", window: snapshot.rateLimit.primary, tint: .blue)
                    resetWindowView(title: "Secondary", window: snapshot.rateLimit.secondary, tint: .cyan)
                }

                Divider()

                resetCreditsView(snapshot.resetCredits)

                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
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

    private func resetWindowView(title: String, window: RateLimitWindow?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(UsageFormatting.timeRemainingText(timestamp: window?.resetsAt, now: now))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            ProgressView(value: Double(window?.usedPercent ?? 0), total: 100)
                .tint(tint)

            HStack {
                Text("\(window?.usedPercent ?? 0)% used")
                Spacer()
                Text("Resets \(UsageFormatting.resetText(timestamp: window?.resetsAt, now: now))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
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
                .buttonStyle(.plain)
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
