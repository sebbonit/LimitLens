import AppKit
import ResetStatCore
import SwiftUI

struct OverviewSectionView: View {
    let summaries: [ProviderUsageSummary]
    let billingExpiries: [BillingExpiry]
    let now: Date
    let hidesProviderNames: Bool
    let onSelectTab: (ProviderTab) -> Void
    var paceProjections: [ProviderTab: PaceProjection] = [:]

    var body: some View {
        SectionBlock {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Overview",
                    detail: overviewDetail,
                    systemImage: "speedometer",
                    hidesProviderNames: hidesProviderNames
                )

                billingExpirySection

                Divider()

                if summaries.isEmpty {
                    StatusLine(icon: "slider.horizontal.3", color: .secondary, text: "No providers enabled.")
                } else {
                    VStack(spacing: 8) {
                        ForEach(summaries) { summary in
                            overviewRow(summary)
                        }
                    }
                }
            }
        }
    }

    private var overviewDetail: String {
        let criticalCount = summaries.filter { $0.severity == .critical }.count
        if criticalCount > 0 {
            return "\(criticalCount) critical"
        }

        let warningCount = summaries.filter { $0.severity == .warning }.count
        if warningCount > 0 {
            return "\(warningCount) warning"
        }

        let unavailableCount = summaries.filter { $0.severity == .unavailable }.count
        if unavailableCount > 0 {
            return "\(unavailableCount) unavailable"
        }

        return summaries.isEmpty ? "Configure providers" : "All clear"
    }

    private func overviewRow(_ summary: ProviderUsageSummary) -> some View {
        Button {
            onSelectTab(summary.tab)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(severityColor(summary.severity).opacity(0.16))
                    Image(systemName: providerIcon(summary.tab.systemImage, hidesProviderNames: hidesProviderNames))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(severityColor(summary.severity))
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(providerName(summary.tab.displayName, privateName: summary.tab.privateName, hidesProviderNames: hidesProviderNames))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(providerSafeMessage(summary.subdetail, hidesProviderNames: hidesProviderNames))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let projection = paceProjections[summary.tab] {
                        Text(projection.summaryText)
                            .font(.system(size: 9))
                            .foregroundStyle(projection.willExhaustBeforeReset ? .orange : .secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(providerSafeMessage(summary.detail, hidesProviderNames: hidesProviderNames))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(summary.severity == .unavailable ? .secondary : .primary)
                    if let secondaryDetail = summary.secondaryDetail {
                        Text(providerSafeMessage(secondaryDetail, hidesProviderNames: hidesProviderNames))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(" ")
                            .font(.caption2.weight(.medium))
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var billingExpirySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Billing & renewals")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(billingSummaryDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                if billingExpiries.isEmpty {
                    Text("No enabled providers")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(billingExpiries) { entry in
                        billingExpiryCell(entry)
                    }
                }
            }
        }
    }

    private func billingExpiryCell(_ entry: BillingExpiry) -> some View {
        let primaryText: String = entry.date.map { UsageFormatting.resetText(date: $0, now: now) } ?? entry.amountText ?? "—"
        let secondaryText: String = entry.date.map { UsageFormatting.relativeDayText(date: $0, now: now) } ?? entry.detailText ?? "No billing"
        let primaryColor: Color = entry.date == nil && entry.amountText == nil ? .secondary : (entry.date == nil ? .primary : expiryColor(entry.urgency))
        return HStack(spacing: 8) {
            Image(systemName: providerIcon(entry.tab.systemImage, hidesProviderNames: hidesProviderNames))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(expiryColor(entry.urgency))
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(providerShortName(entry.tab, hidesProviderNames: hidesProviderNames))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(entry.label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(primaryText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)
                Text(secondaryText)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private var billingSummaryDetail: String {
        let expiring = billingExpiries.filter { $0.urgency == .expired || $0.urgency == .soon }.count
        if expiring > 0 { return "\(expiring) expiring soon" }
        let warn = billingExpiries.filter { $0.urgency == .warning }.count
        if warn > 0 { return "\(warn) within 2w" }
        let healthy = billingExpiries.filter { $0.urgency == .healthy }.count
        if healthy > 0 { return "Up to date" }
        return "—"
    }
}
