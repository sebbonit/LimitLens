import AppKit
import LimitLensCore
import SwiftUI

/// Keeps custom controls easy to target when their visual treatment is smaller
/// than the area users should be able to click.
struct CompactHitTargetButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .frame(minWidth: 28, minHeight: 28)
    }
}

private struct AppAppearanceKey: EnvironmentKey {
    static let defaultValue: AppAppearance = .classic
}

extension EnvironmentValues {
    var appAppearance: AppAppearance {
        get { self[AppAppearanceKey.self] }
        set { self[AppAppearanceKey.self] = newValue }
    }
}

extension AppAppearance {
    var popoverWidth: CGFloat {
        switch self {
        case .classic: return 460
        case .studio: return 680
        case .terminal: return 620
        case .pulse: return 500
        case .harbor: return 540
        case .constellation: return 720
        }
    }

    var outerPadding: CGFloat {
        switch self {
        case .classic: return 12
        case .studio: return 16
        case .terminal: return 8
        case .pulse: return 14
        case .harbor: return 13
        case .constellation: return 14
        }
    }

    var panelCornerRadius: CGFloat {
        switch self {
        case .classic: return 7
        case .studio: return 15
        case .terminal: return 2
        case .pulse: return 20
        case .harbor: return 10
        case .constellation: return 22
        }
    }

    var cardCornerRadius: CGFloat {
        switch self {
        case .classic: return 8
        case .studio: return 12
        case .terminal: return 1
        case .pulse: return 16
        case .harbor: return 10
        case .constellation: return 18
        }
    }

    var accentColor: Color {
        switch self {
        case .classic: return .accentColor
        case .studio: return .indigo
        case .terminal: return .green
        case .pulse: return Color(red: 0.96, green: 0.42, blue: 0.18)
        case .harbor: return Color(red: 0.08, green: 0.58, blue: 0.62)
        case .constellation: return Color(red: 0.69, green: 0.52, blue: 1)
        }
    }

    var preferredColorScheme: ColorScheme? {
        self == .terminal || self == .constellation ? .dark : nil
    }

    func windowBackground(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .classic:
            return Color(nsColor: .windowBackgroundColor)
        case .studio:
            switch colorScheme {
            case .dark:
                return Color(red: 0.09, green: 0.095, blue: 0.14)
            default:
                return Color(red: 0.945, green: 0.95, blue: 0.975)
            }
        case .terminal:
            return Color(red: 0.025, green: 0.032, blue: 0.028)
        case .pulse:
            switch colorScheme {
            case .dark:
                return Color(red: 0.08, green: 0.07, blue: 0.065)
            default:
                return Color(red: 0.985, green: 0.965, blue: 0.945)
            }
        case .harbor:
            switch colorScheme {
            case .dark:
                return Color(red: 0.06, green: 0.09, blue: 0.10)
            default:
                return Color(red: 0.93, green: 0.96, blue: 0.965)
            }
        case .constellation:
            return Color(red: 0.025, green: 0.022, blue: 0.060)
        }
    }

    func panelBackground(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .classic:
            return Color(nsColor: .controlBackgroundColor)
        case .studio:
            switch colorScheme {
            case .dark:
                return Color(red: 0.12, green: 0.125, blue: 0.18)
            default:
                return .white
            }
        case .terminal:
            return Color(red: 0.035, green: 0.055, blue: 0.043)
        case .pulse:
            switch colorScheme {
            case .dark:
                return Color(red: 0.13, green: 0.115, blue: 0.105)
            default:
                return Color(red: 1.0, green: 0.99, blue: 0.98)
            }
        case .harbor:
            switch colorScheme {
            case .dark:
                return Color(red: 0.09, green: 0.13, blue: 0.145)
            default:
                return Color(red: 0.975, green: 0.99, blue: 0.992)
            }
        case .constellation:
            return Color(red: 0.055, green: 0.047, blue: 0.115)
        }
    }

    func cardBackground(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .studio:
            switch colorScheme {
            case .dark:
                return Color(red: 0.15, green: 0.155, blue: 0.22)
            default:
                return .white
            }
        case .pulse:
            switch colorScheme {
            case .dark:
                return Color(red: 0.16, green: 0.14, blue: 0.125)
            default:
                return .white
            }
        case .harbor:
            switch colorScheme {
            case .dark:
                return Color(red: 0.11, green: 0.155, blue: 0.17)
            default:
                return .white
            }
        case .constellation:
            return Color(red: 0.075, green: 0.063, blue: 0.145)
        default:
            return panelBackground(for: colorScheme)
        }
    }

    func studioShadowColor(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color.black.opacity(0.28)
        default:
            return Color.indigo.opacity(0.08)
        }
    }

    func pulseShadowColor(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color.black.opacity(0.34)
        default:
            return accentColor.opacity(0.12)
        }
    }

    func harborShadowColor(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return Color.black.opacity(0.30)
        default:
            return accentColor.opacity(0.10)
        }
    }

    func constellationShadowColor(for colorScheme: ColorScheme) -> Color {
        Color(red: 0.36, green: 0.18, blue: 0.82).opacity(0.30)
    }
}

struct ConstellationPanelShape: Shape {
    var cornerRadius: CGFloat = 18
    var cut: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, min(rect.width, rect.height) / 2)
        let chamfer = min(cut, min(rect.width, rect.height) / 3)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - chamfer, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + chamfer))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + chamfer, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - chamfer))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

struct SectionBlock<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.appAppearance) private var appearance
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content
            .padding(appearance == .terminal ? 8 : (appearance == .pulse || appearance == .harbor || appearance == .constellation ? 12 : 10))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    if appearance == .constellation {
                        ConstellationPanelShape(cornerRadius: appearance.panelCornerRadius, cut: 18)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        appearance.panelBackground(for: colorScheme),
                                        appearance.cardBackground(for: colorScheme).opacity(0.72)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: appearance.panelCornerRadius, style: .continuous)
                            .fill(appearance.panelBackground(for: colorScheme))
                    }
                }
            )
            .overlay(
                Group {
                    if appearance == .constellation {
                        ConstellationPanelShape(cornerRadius: appearance.panelCornerRadius, cut: 18)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        appearance.accentColor.opacity(0.50),
                                        Color.cyan.opacity(0.12),
                                        appearance.accentColor.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    } else {
                        RoundedRectangle(cornerRadius: appearance.panelCornerRadius, style: .continuous)
                            .stroke(
                                appearance == .terminal
                                    ? Color.green.opacity(0.26)
                                    : appearance.accentColor.opacity(appearance == .pulse || appearance == .harbor ? 0.14 : 0.10),
                                lineWidth: appearance == .terminal || appearance == .pulse || appearance == .harbor ? 1 : 0.5
                            )
                    }
                }
            )
            .overlay(alignment: .topTrailing) {
                if appearance == .constellation {
                    Circle()
                        .fill(Color.cyan.opacity(0.85))
                        .frame(width: 4, height: 4)
                        .shadow(color: .cyan.opacity(0.8), radius: 5)
                        .padding(.top, 9)
                        .padding(.trailing, 12)
                }
            }
            .shadow(
                color: sectionShadowColor,
                radius: sectionShadowRadius,
                y: sectionShadowY
            )
    }

    private var sectionShadowColor: Color {
        switch appearance {
        case .studio: return appearance.studioShadowColor(for: colorScheme)
        case .pulse: return appearance.pulseShadowColor(for: colorScheme)
        case .harbor: return appearance.harborShadowColor(for: colorScheme)
        case .constellation: return appearance.constellationShadowColor(for: colorScheme)
        default: return .clear
        }
    }

    private var sectionShadowRadius: CGFloat {
        switch appearance {
        case .studio: return 8
        case .pulse: return 10
        case .harbor: return 6
        case .constellation: return 14
        default: return 0
        }
    }

    private var sectionShadowY: CGFloat {
        switch appearance {
        case .studio: return 3
        case .pulse: return 4
        case .harbor: return 2
        case .constellation: return 5
        default: return 0
        }
    }
}

extension NSScroller {
    static func forceOverlayScrollers() {
        // Force overlay scrollers for this process so they stay visible
        // instead of auto-hiding based on the user's system preference.
        UserDefaults.standard.set(false, forKey: "AppleShowScrollBars")
        UserDefaults.standard.synchronize()
    }
}

struct DailyUsageChart: View {
    let buckets: [AccountTokenUsageDailyBucket]
    @State private var hoveredBucketIndex: Int?
    @Environment(\.appAppearance) private var appearance
    @Environment(\.colorScheme) private var colorScheme

    private static let isoDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let tooltipDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var displayedBuckets: [AccountTokenUsageDailyBucket] {
        DailyUsageChartBuckets.displayed(from: buckets)
    }

    private var maxTokens: Int64 {
        max(displayedBuckets.map(\.tokens).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent Codex tokens")
                    .font(.caption2.weight(.semibold))
                Spacer()
                Text("\(displayedBuckets.count)d")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(Array(displayedBuckets.enumerated()), id: \.offset) { index, bucket in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color.accentColor.opacity(barOpacity(at: index)))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: barHeight(for: bucket.tokens))
                                    .shadow(
                                        color: hoveredBucketIndex == index ? Color.accentColor.opacity(0.28) : .clear,
                                        radius: 3,
                                        y: 1
                                    )
                                Text(dayLabel(bucket.startDate))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(hoveredBucketIndex == index ? Color.primary : Color.secondary.opacity(0.62))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 54, alignment: .bottom)
                            .contentShape(Rectangle())
                            .scaleEffect(
                                x: hoveredBucketIndex == index ? 1.035 : 1,
                                y: hoveredBucketIndex == index ? 1.04 : 1,
                                anchor: .bottom
                            )
                            .onHover { isHovered in
                                if isHovered {
                                    hoveredBucketIndex = index
                                } else if hoveredBucketIndex == index {
                                    hoveredBucketIndex = nil
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(tooltipText(for: bucket))
                        }
                    }
                    .frame(height: 62)

                    if let hoveredBucketIndex,
                       displayedBuckets.indices.contains(hoveredBucketIndex) {
                        hoverTooltip(for: displayedBuckets[hoveredBucketIndex])
                            .position(
                                x: tooltipX(
                                    for: hoveredBucketIndex,
                                    chartWidth: geometry.size.width
                                ),
                                y: 15
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                            .zIndex(1)
                    }
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .bottom
                )
            }
            .frame(height: 94)
            .animation(.easeOut(duration: 0.08), value: hoveredBucketIndex)
        }
    }

    private func hoverTooltip(for bucket: AccountTokenUsageDailyBucket) -> some View {
        HStack(spacing: 6) {
            Text(tooltipDateText(for: bucket))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            Circle()
                .fill(Color.accentColor.opacity(0.65))
                .frame(width: 4, height: 4)

            Text(UsageFormatting.compactNumber(bucket.tokens))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)

            Text("tokens")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(width: 202)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(appearance.cardBackground(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.accentColor.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 6, y: 2)
        .allowsHitTesting(false)
    }

    private func barHeight(for tokens: Int64) -> CGFloat {
        let ratio = CGFloat(Double(tokens) / Double(maxTokens))
        return max(4, ratio * 42)
    }

    private func dayLabel(_ startDate: String) -> String {
        guard let day = startDate.split(separator: "-").last else { return startDate }
        return String(day)
    }

    private func barOpacity(at index: Int) -> Double {
        guard let hoveredBucketIndex else { return 0.78 }
        return hoveredBucketIndex == index ? 0.98 : 0.38
    }

    private func tooltipX(for index: Int, chartWidth: CGFloat) -> CGFloat {
        let tooltipHalfWidth: CGFloat = 101
        guard chartWidth > tooltipHalfWidth * 2, !displayedBuckets.isEmpty else {
            return chartWidth / 2
        }

        let barCenter = chartWidth * (CGFloat(index) + 0.5) / CGFloat(displayedBuckets.count)
        return min(max(barCenter, tooltipHalfWidth), chartWidth - tooltipHalfWidth)
    }

    private func tooltipDateText(for bucket: AccountTokenUsageDailyBucket) -> String {
        guard let date = Self.isoDayFormatter.date(from: bucket.startDate) else {
            return bucket.startDate
        }
        return Self.tooltipDayFormatter.string(from: date)
    }

    private func tooltipText(for bucket: AccountTokenUsageDailyBucket) -> String {
        let count = UsageFormatting.compactNumber(bucket.tokens)
        return "\(tooltipDateText(for: bucket)) · \(count) tokens"
    }
}

struct UsageCard: View {
    let label: String
    let percentUsed: Double?
    let leadingDetail: String?
    let trailingDetail: String?
    let tint: Color
    @Environment(\.appAppearance) private var appearance

    private var clampedPercent: Double {
        min(max(percentUsed ?? 0, 0), 100)
    }

    @ViewBuilder
    var body: some View {
        switch appearance {
        case .classic:
            classicCard
        case .studio:
            studioCard
        case .terminal:
            terminalCard
        case .pulse:
            pulseCard
        case .harbor:
            harborCard
        case .constellation:
            constellationCard
        }
    }

    private var classicCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(percentText(percentUsed))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(percentUsed == nil ? .secondary : .primary)
            }

            ProgressView(value: clampedPercent, total: 100)
                .controlSize(.small)
                .tint(tint)

            if leadingDetail != nil || trailingDetail != nil {
                HStack(spacing: 6) {
                    if let leadingDetail {
                        Text(leadingDetail)
                            .layoutPriority(1)
                    }
                    Spacer(minLength: 4)
                    if let trailingDetail {
                        Text(trailingDetail)
                            .layoutPriority(1)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 9)
        .padding(.top, 9)
        .padding(.bottom, 12)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
        )
    }

    private var studioCard: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.12), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: clampedPercent / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(percentText(percentUsed))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(tint)
                if let leadingDetail {
                    Text(leadingDetail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                if let trailingDetail {
                    Text(trailingDetail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
    }

    private var terminalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("[\(label.uppercased())]")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.green)
                Spacer()
                Text(percentText(percentUsed))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.72, green: 1, blue: 0.76))
            }

            HStack(spacing: 3) {
                ForEach(0..<12, id: \.self) { index in
                    Rectangle()
                        .fill(Double(index) < clampedPercent / (100.0 / 12.0) ? Color.green : Color.green.opacity(0.14))
                        .frame(height: 7)
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Text(leadingDetail ?? "NO RESET DATA")
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let trailingDetail {
                    Text(trailingDetail)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Color(red: 0.60, green: 0.74, blue: 0.63))
            .lineLimit(2)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(Color.black.opacity(0.26))
        .overlay(Rectangle().stroke(Color.green.opacity(0.32), lineWidth: 1))
    }

    private var pulseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Spacer(minLength: 4)
                Text(percentText(percentUsed))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(percentUsed == nil ? .secondary : .primary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tint.opacity(0.12))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(8, geometry.size.width * clampedPercent / 100))
                }
            }
            .frame(height: 10)

            if leadingDetail != nil || trailingDetail != nil {
                HStack(spacing: 8) {
                    if let leadingDetail {
                        Text(leadingDetail)
                            .layoutPriority(1)
                    }
                    Spacer(minLength: 4)
                    if let trailingDetail {
                        Text(trailingDetail)
                            .layoutPriority(1)
                    }
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private var harborCard: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(tint)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                    Spacer(minLength: 4)
                    Text(percentText(percentUsed))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(percentUsed == nil ? .secondary : .primary)
                }

                GeometryReader { geometry in
                    let fillWidth = geometry.size.width * clampedPercent / 100
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(tint.opacity(0.12))
                        if fillWidth > 0 {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [tint.opacity(0.75), tint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: fillWidth)
                        }
                    }
                }
                .frame(height: 5)

                if leadingDetail != nil || trailingDetail != nil {
                    HStack(alignment: .top, spacing: 6) {
                        if let leadingDetail {
                            Text(leadingDetail)
                                .layoutPriority(1)
                        }
                        Spacer(minLength: 4)
                        if let trailingDetail {
                            Text(trailingDetail)
                                .layoutPriority(1)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(tint.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private var constellationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HStack(spacing: 6) {
                    Diamond()
                        .fill(tint)
                        .frame(width: 8, height: 8)
                        .shadow(color: tint.opacity(0.7), radius: 5)
                    Text(label.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(tint.opacity(0.92))
                }
                Spacer(minLength: 6)
                Text(percentText(percentUsed))
                    .font(.system(size: 21, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(percentUsed == nil ? Color.secondary : Color.white)
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<18, id: \.self) { index in
                    let isFilled = Double(index) < clampedPercent / (100.0 / 18.0)
                    Capsule()
                        .fill(isFilled ? tint : Color.white.opacity(0.08))
                        .frame(maxWidth: .infinity)
                        .frame(height: index.isMultiple(of: 3) ? 11 : 6)
                        .shadow(color: isFilled ? tint.opacity(0.35) : .clear, radius: 3)
                }
            }
            .frame(height: 11, alignment: .bottom)

            if leadingDetail != nil || trailingDetail != nil {
                HStack(alignment: .top, spacing: 8) {
                    if let leadingDetail {
                        Text(leadingDetail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let trailingDetail {
                        Text(trailingDetail)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.52))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.12), Color.white.opacity(0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: ConstellationPanelShape(cornerRadius: 16, cut: 14)
        )
        .overlay(
            ConstellationPanelShape(cornerRadius: 16, cut: 14)
                .stroke(tint.opacity(0.24), lineWidth: 1)
        )
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    var caption: String?
    var captionColor: Color = .secondary
    @Environment(\.appAppearance) private var appearance

    @ViewBuilder
    var body: some View {
        switch appearance {
        case .classic:
            metricContent
        case .studio:
            metricContent
                .padding(11)
                .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
                .background(Color.indigo.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
        case .terminal:
            metricContent
                .padding(9)
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
                .foregroundStyle(Color(red: 0.76, green: 1, blue: 0.79))
                .background(Color.black.opacity(0.22))
                .overlay(Rectangle().stroke(Color.green.opacity(0.22), lineWidth: 1))
        case .pulse:
            metricContent
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(appearance.accentColor.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(appearance.accentColor.opacity(0.14), lineWidth: 1)
                )
        case .harbor:
            metricContent
                .padding(11)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(appearance.accentColor.opacity(0.05))
                )
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(appearance.accentColor.opacity(0.55))
                        .frame(width: 2.5)
                        .padding(.vertical, 10)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(appearance.accentColor.opacity(0.12), lineWidth: 1)
                )
        case .constellation:
            metricContent
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
                .background(
                    LinearGradient(
                        colors: [
                            appearance.accentColor.opacity(0.11),
                            Color.cyan.opacity(0.025)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: ConstellationPanelShape(cornerRadius: 14, cut: 12)
                )
                .overlay(
                    ConstellationPanelShape(cornerRadius: 14, cut: 12)
                        .stroke(appearance.accentColor.opacity(0.22), lineWidth: 1)
                )
        }
    }

    private var metricContent: some View {
        VStack(alignment: .leading, spacing: appearance == .studio || appearance == .pulse || appearance == .harbor || appearance == .constellation ? 5 : 3) {
            Text(title)
                .font(
                    appearance == .terminal
                        ? .system(size: 9, weight: .bold, design: .monospaced)
                        : appearance == .constellation
                            ? .system(size: 9, weight: .bold, design: .rounded)
                            : .caption2.weight(.medium)
                )
                .tracking(appearance == .constellation ? 0.9 : 0)
                .foregroundStyle(appearance == .terminal ? Color.green.opacity(0.62) : Color.secondary)
            Text(value)
                .font(appearance == .studio || appearance == .pulse || appearance == .harbor || appearance == .constellation ? .title3.weight(.bold) : .body.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(captionColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct StatusLine: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 14)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PaceProjectionLine: View {
    let projection: PaceProjection

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: projection.willExhaustBeforeReset ? "exclamationmark.triangle" : "checkmark.circle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(projection.willExhaustBeforeReset ? .orange : .secondary)
            Text(projection.summaryText)
                .font(.caption2)
                .foregroundStyle(projection.willExhaustBeforeReset ? .orange : .secondary)
        }
    }
}

struct PaceCollectingLine: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Collecting pace data...")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct QuotaPaceChart: View {
    let data: QuotaPaceChartData
    let tint: Color

    @Environment(\.appAppearance) private var appearance
    @Environment(\.colorScheme) private var colorScheme

    private let yTicks = [100, 75, 50, 25, 0]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(data.quotaLabel) pace")
                    .font(.caption2.weight(.semibold))
                Spacer()
                Text("\(Int(data.currentPercentRemaining.rounded()))% remaining")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(markerColor)
            }

            HStack(spacing: 13) {
                chartLegend(title: "Target", color: .green, dashed: true)
                chartLegend(title: "Actual", color: tint, dashed: false)
                chartLegend(title: "Current", color: projectionColor, dashed: true)
                if data.historicalPercentUsedPerDay != nil {
                    chartLegend(title: "Historical", color: .secondary, dashed: true)
                }
            }

            GeometryReader { geometry in
                let plot = CGRect(
                    x: 31,
                    y: 28,
                    width: max(1, geometry.size.width - 38),
                    height: max(1, geometry.size.height - 50)
                )

                ZStack {
                    Canvas { context, _ in
                        drawGrid(in: &context, plot: plot)
                        drawTarget(in: &context, plot: plot)
                        drawActual(in: &context, plot: plot)
                        drawForecasts(in: &context, plot: plot)
                    }

                    ForEach(yTicks, id: \.self) { tick in
                        Text("\(tick)%")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.secondary.opacity(0.78))
                            .position(
                                x: 13,
                                y: yPosition(percentRemaining: Double(tick), plot: plot)
                            )
                    }

                    ForEach(Array(xAxisDates.enumerated()), id: \.offset) { _, date in
                        Text(xAxisLabel(for: date))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.secondary.opacity(0.78))
                            .lineLimit(1)
                            .position(
                                x: xPosition(date: date, plot: plot),
                                y: plot.maxY + 13
                            )
                    }

                    currentMarker(in: plot)
                }
            }
            .frame(height: 162)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
        }
    }

    private func chartLegend(title: String, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 5) {
            Canvas { context, size in
                var line = Path()
                line.move(to: CGPoint(x: 0, y: size.height / 2))
                line.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                context.stroke(
                    line,
                    with: .color(color),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        dash: dashed ? [3, 2] : []
                    )
                )
            }
            .frame(width: 16, height: 6)

            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func drawGrid(in context: inout GraphicsContext, plot: CGRect) {
        for tick in yTicks {
            let y = yPosition(percentRemaining: Double(tick), plot: plot)
            var line = Path()
            line.move(to: CGPoint(x: plot.minX, y: y))
            line.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.stroke(
                line,
                with: .color(Color.secondary.opacity(0.16)),
                style: StrokeStyle(lineWidth: 0.7, dash: [2, 3])
            )
        }

        for date in xAxisDates {
            let x = xPosition(date: date, plot: plot)
            var line = Path()
            line.move(to: CGPoint(x: x, y: plot.minY))
            line.addLine(to: CGPoint(x: x, y: plot.maxY))
            context.stroke(
                line,
                with: .color(Color.secondary.opacity(0.12)),
                style: StrokeStyle(lineWidth: 0.7, dash: [2, 3])
            )
        }
    }

    private func drawTarget(in context: inout GraphicsContext, plot: CGRect) {
        var target = Path()
        target.move(to: point(date: data.cycleStart, percentUsed: 0, plot: plot))
        let endpoint = point(
            date: data.resetAt,
            percentUsed: 100 - data.safetyBufferPercent,
            plot: plot
        )
        target.addLine(to: endpoint)
        context.stroke(
            target,
            with: .color(Color.green.opacity(0.9)),
            style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])
        )
        context.fill(
            Path(ellipseIn: CGRect(x: endpoint.x - 3, y: endpoint.y - 3, width: 6, height: 6)),
            with: .color(.green)
        )
    }

    private func drawActual(in context: inout GraphicsContext, plot: CGRect) {
        let points = actualSamples.map {
            point(date: $0.timestamp, percentUsed: $0.percentUsed, plot: plot)
        }
        guard let first = points.first else { return }

        if points.count > 1 {
            var actual = Path()
            actual.move(to: first)
            var previous = first
            for point in points.dropFirst() {
                actual.addLine(to: CGPoint(x: point.x, y: previous.y))
                actual.addLine(to: point)
                previous = point
            }
            context.stroke(
                actual,
                with: .color(tint),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawForecasts(in context: inout GraphicsContext, plot: CGRect) {
        drawForecast(
            rate: data.currentPercentUsedPerDay,
            color: projectionColor,
            dash: [7, 3],
            lineWidth: 2,
            startDate: observationDate,
            startPercentUsed: data.currentPercentUsed,
            context: &context,
            plot: plot
        )
        if let historicalRate = data.historicalPercentUsedPerDay {
            drawForecast(
                rate: historicalRate,
                color: .secondary,
                dash: [2, 3],
                lineWidth: 1.3,
                startDate: data.cycleStart,
                startPercentUsed: 0,
                context: &context,
                plot: plot
            )
        }

        var nowRule = Path()
        let nowX = currentPoint(in: plot).x
        nowRule.move(to: CGPoint(x: nowX, y: plot.minY - 7))
        nowRule.addLine(to: CGPoint(x: nowX, y: plot.maxY))
        context.stroke(
            nowRule,
            with: .color(Color.secondary.opacity(0.28)),
            style: StrokeStyle(lineWidth: 0.8, dash: [2, 3])
        )
    }

    private func drawForecast(
        rate: Double,
        color: Color,
        dash: [CGFloat],
        lineWidth: CGFloat,
        startDate: Date,
        startPercentUsed: Double,
        context: inout GraphicsContext,
        plot: CGRect
    ) {
        let forecastPoints = forecastPoints(
            rate: rate,
            startDate: startDate,
            startPercentUsed: startPercentUsed
        )
        guard let first = forecastPoints.first else { return }
        var forecast = Path()
        forecast.move(to: point(date: first.date, percentUsed: first.percentUsed, plot: plot))
        for forecastPoint in forecastPoints.dropFirst() {
            forecast.addLine(
                to: point(
                    date: forecastPoint.date,
                    percentUsed: forecastPoint.percentUsed,
                    plot: plot
                )
            )
        }
        context.stroke(
            forecast,
            with: .color(color.opacity(0.9)),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: dash)
        )

        let markedPoint = forecastPoints[forecastPoints.count - 1]
        let endpoint = point(
            date: markedPoint.date,
            percentUsed: markedPoint.percentUsed,
            plot: plot
        )
        context.fill(
            Path(ellipseIn: CGRect(x: endpoint.x - 2.5, y: endpoint.y - 2.5, width: 5, height: 5)),
            with: .color(color)
        )
    }

    private func currentMarker(in plot: CGRect) -> some View {
        let current = currentPoint(in: plot)

        return ZStack {
            Circle()
                .fill(markerColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(appearance.cardBackground(for: colorScheme), lineWidth: 1.5)
                )
                .position(current)

            Text("NOW")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(markerColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(appearance.cardBackground(for: colorScheme))
                        .overlay(
                            Capsule()
                                .stroke(markerColor.opacity(0.38), lineWidth: 0.75)
                        )
                )
                .position(x: current.x, y: 10)
        }
        .allowsHitTesting(false)
    }

    private var actualSamples: [PaceSample] {
        let local = data.samples
            .filter { $0.timestamp >= data.cycleStart && $0.timestamp <= data.resetAt }
            .sorted { $0.timestamp < $1.timestamp }

        var samples = [
            PaceSample(percentUsed: 0, timestamp: data.cycleStart)
        ] + local
        let currentDate = observationDate
        if let last = samples.last, abs(last.timestamp.timeIntervalSince(currentDate)) < 1 {
            samples[samples.count - 1] = PaceSample(
                percentUsed: data.currentPercentUsed,
                timestamp: currentDate
            )
        } else {
            samples.append(
                PaceSample(percentUsed: data.currentPercentUsed, timestamp: currentDate)
            )
        }
        return samples
    }

    private func forecastPoints(
        rate: Double,
        startDate: Date,
        startPercentUsed: Double
    ) -> [(date: Date, percentUsed: Double)] {
        let current = (date: startDate, percentUsed: startPercentUsed)
        guard rate > 0 else {
            return [current, (data.resetAt, startPercentUsed)]
        }
        let exhaustionDate = startDate.addingTimeInterval(
            (100 - startPercentUsed) / rate * 86_400
        )
        if exhaustionDate < data.resetAt {
            return [current, (exhaustionDate, 100)]
        }
        let daysLeft = max(data.resetAt.timeIntervalSince(startDate) / 86_400, 0)
        return [
            current,
            (data.resetAt, min(100, startPercentUsed + rate * daysLeft))
        ]
    }

    private var projectionColor: Color {
        if data.projection?.willExhaustBeforeReset == true {
            return .red
        }
        if let historicalRate = data.historicalPercentUsedPerDay,
           data.currentPercentUsedPerDay > historicalRate {
            return .red
        }
        return tint
    }

    private var markerColor: Color {
        projectionColor
    }

    private func currentPoint(in plot: CGRect) -> CGPoint {
        point(
            date: observationDate,
            percentUsed: data.currentPercentUsed,
            plot: plot
        )
    }

    private var observationDate: Date {
        let latest = data.samples.max(by: { $0.timestamp < $1.timestamp })?.timestamp
            ?? data.now
        return min(max(latest, data.cycleStart), data.resetAt)
    }

    private func point(date: Date, percentUsed: Double, plot: CGRect) -> CGPoint {
        let duration = data.resetAt.timeIntervalSince(data.cycleStart)
        let elapsed = date.timeIntervalSince(data.cycleStart)
        let xFraction = max(0, min(1, elapsed / max(duration, 1)))
        let yFraction = max(0, min(1, percentUsed / 100))
        return CGPoint(
            x: plot.minX + plot.width * CGFloat(xFraction),
            y: plot.minY + plot.height * CGFloat(yFraction)
        )
    }

    private func yPosition(percentRemaining: Double, plot: CGRect) -> CGFloat {
        plot.minY + plot.height * CGFloat((100 - percentRemaining) / 100)
    }

    private func xPosition(date: Date, plot: CGRect) -> CGFloat {
        let duration = max(data.resetAt.timeIntervalSince(data.cycleStart), 1)
        let elapsed = date.timeIntervalSince(data.cycleStart)
        let fraction = max(0, min(1, elapsed / duration))
        return plot.minX + plot.width * CGFloat(fraction)
    }

    private var xAxisDates: [Date] {
        let duration = data.resetAt.timeIntervalSince(data.cycleStart)
        if duration > 2 * 86_400, duration <= 10 * 86_400 {
            var dates = [data.cycleStart]
            var date = data.cycleStart.addingTimeInterval(86_400)
            while date < data.resetAt {
                dates.append(date)
                date = date.addingTimeInterval(86_400)
            }
            dates.append(data.resetAt)
            return dates
        }

        return (0..<5).map { index in
            data.cycleStart.addingTimeInterval(duration * Double(index) / 4)
        }
    }

    private func xAxisLabel(for date: Date) -> String {
        let duration = data.resetAt.timeIntervalSince(data.cycleStart)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if duration <= 2 * 86_400 {
            formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        } else if duration <= 10 * 86_400 {
            if date == data.cycleStart || date == data.resetAt {
                formatter.setLocalizedDateFormatFromTemplate("MMM d")
            } else {
                formatter.setLocalizedDateFormatFromTemplate("EEE")
            }
        } else {
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
        }
        return formatter.string(from: date)
    }

    private var accessibilityText: String {
        let remaining = Int(data.currentPercentRemaining.rounded())
        let reset = UsageFormatting.resetText(date: data.resetAt, now: data.now)
        let projection = data.projection?.summaryText ?? "Projection is still collecting data"
        return "\(data.quotaLabel) quota pace. \(remaining) percent remaining. Resets \(reset). \(projection)."
    }
}

enum LimitLensArtwork {
    static let image: NSImage = {
        let bundledURL = Bundle.main.url(forResource: "LimitLens", withExtension: "icns")
        let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/LimitLens.icns")

        return bundledURL.flatMap(NSImage.init(contentsOf:))
            ?? NSImage(contentsOf: sourceURL)
            ?? NSImage(size: NSSize(width: 512, height: 512))
    }()
}

struct LimitLensMark: View {
    var body: some View {
        Image(nsImage: LimitLensArtwork.image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

// MARK: - Shared popover helpers

func providerName(_ name: String, privateName: String, hidesProviderNames: Bool) -> String {
    hidesProviderNames ? privateName : name
}

func providerSafeMessage(_ message: String, hidesProviderNames: Bool) -> String {
    guard hidesProviderNames else { return message }
    return message
        .replacingOccurrences(of: "Codex", with: "Provider")
        .replacingOccurrences(of: "Cursor", with: "Provider")
        .replacingOccurrences(of: "Devin", with: "Provider")
        .replacingOccurrences(of: "OpenCode Go", with: "Provider")
        .replacingOccurrences(of: "OpenCode", with: "Provider")
}

func providerIcon(_ systemImage: String, hidesProviderNames: Bool) -> String {
    hidesProviderNames ? "circle.grid.2x2" : systemImage
}

func providerShortName(_ tab: ProviderTab, hidesProviderNames: Bool) -> String {
    if hidesProviderNames {
        switch tab {
        case .codex: return "P1"
        case .cursor: return "P2"
        case .devin: return "P3"
        case .openCodeGo: return "P4"
        default: return tab.privateName
        }
    }
    switch tab {
    case .codex: return "Codex"
    case .cursor: return "Cursor"
    case .devin: return "Devin"
    case .openCodeGo: return "Go"
    default: return tab.displayName
    }
}

func severityColor(_ severity: UsageSeverity) -> Color {
    switch severity {
    case .critical: return .red
    case .warning: return .orange
    case .healthy: return .green
    case .unavailable: return .secondary
    }
}

func expiryColor(_ urgency: UsageFormatting.ExpiryUrgency) -> Color {
    switch urgency {
    case .expired: return .red
    case .soon: return .orange
    case .warning: return .yellow
    case .healthy: return .green
    case .unknown: return .secondary
    }
}

func percentText(_ value: Double?) -> String {
    guard let value else { return "--" }
    return "\(Int(value.rounded()))%"
}

func streakText(_ days: Int64?) -> String {
    guard let days else { return "--" }
    return days == 1 ? "1 day" : "\(days) days"
}

func quotaPercentText(_ remainingPercent: Int?) -> String {
    guard let remainingPercent else { return "-- remaining" }
    return "\(remainingPercent)% remaining"
}

func cursorResetText(_ date: Date?, now: Date) -> String {
    guard let date else { return "unknown" }
    return UsageFormatting.resetText(date: date, now: now)
}

func quotaResetText(_ date: Date?, now: Date) -> String {
    guard let date else { return "unknown" }
    return UsageFormatting.resetText(date: date, now: now)
}

func advancedResetDate(_ date: Date?, interval: TimeInterval, now: Date) -> Date? {
    guard var date else { return nil }
    while date < now {
        date = date.addingTimeInterval(interval)
    }
    return date
}

struct SectionHeader: View {
    let title: String
    let detail: String?
    let systemImage: String
    let hidesProviderNames: Bool
    var dashboardURL: URL? = nil
    var isRefreshing: Bool = false
    var lastUpdated: Date? = nil
    var onRefresh: (() -> Void)? = nil
    @Environment(\.appAppearance) private var appearance

    @ViewBuilder
    var body: some View {
        switch appearance {
        case .classic:
            classicHeader
        case .studio:
            studioHeader
        case .terminal:
            terminalHeader
        case .pulse:
            pulseHeader
        case .harbor:
            harborHeader
        case .constellation:
            constellationHeader
        }
    }

    private var classicHeader: some View {
        HStack(spacing: 7) {
            Image(systemName: providerIcon(systemImage, hidesProviderNames: hidesProviderNames))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(title)
                .font(.subheadline.weight(.semibold))

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            headerControls
        }
    }

    private var studioHeader: some View {
        HStack(spacing: 11) {
            Image(systemName: providerIcon(systemImage, hidesProviderNames: hidesProviderNames))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(appearance.accentColor)
                .frame(width: 34, height: 34)
                .background(appearance.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.title3.weight(.semibold))
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            headerControls
        }
        .padding(.bottom, 2)
    }

    private var terminalHeader: some View {
        HStack(spacing: 9) {
            Text("::")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(Color.green)
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.76, green: 1, blue: 0.79))
                if let detail, !detail.isEmpty {
                    Text(detail.uppercased())
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.green.opacity(0.62))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            headerControls
        }
        .padding(.bottom, 3)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.green.opacity(0.28)).frame(height: 1)
        }
    }

    private var pulseHeader: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(appearance.accentColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(appearance.accentColor.opacity(0.35), lineWidth: 4)
                        .frame(width: 16, height: 16)
                )
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.headline.weight(.semibold))
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            headerControls
        }
        .padding(.bottom, 2)
    }

    private var harborHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: providerIcon(systemImage, hidesProviderNames: hidesProviderNames))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(appearance.accentColor)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(appearance.accentColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            headerControls
        }
        .padding(.bottom, 2)
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [appearance.accentColor.opacity(0.35), appearance.accentColor.opacity(0.05), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1.5)
        }
    }

    private var constellationHeader: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .stroke(appearance.accentColor.opacity(0.18), lineWidth: 1)
                    .frame(width: 35, height: 35)
                Circle()
                    .trim(from: 0.08, to: 0.70)
                    .stroke(
                        AngularGradient(
                            colors: [appearance.accentColor, .cyan, appearance.accentColor],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-38))
                    .frame(width: 29, height: 29)
                Image(systemName: providerIcon(systemImage, hidesProviderNames: hidesProviderNames))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("NODE / \(title.uppercased())")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(appearance.accentColor)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.56))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            headerControls
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            HStack(spacing: 5) {
                Circle()
                    .fill(appearance.accentColor)
                    .frame(width: 4, height: 4)
                    .shadow(color: appearance.accentColor, radius: 4)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [appearance.accentColor.opacity(0.55), Color.cyan.opacity(0.12), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private var headerControls: some View {
        if let lastUpdated {
            Text(lastUpdated.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(appearance == .terminal ? Color.green.opacity(0.65) : Color.secondary)
                .help("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
        }

        if let dashboardURL {
            Button {
                NSWorkspace.shared.open(dashboardURL)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(CompactHitTargetButtonStyle())
            .foregroundStyle(appearance == .terminal ? Color.green : Color.secondary)
            .help("Open dashboard")
        }

        if let onRefresh {
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
            }
            .buttonStyle(CompactHitTargetButtonStyle())
            .foregroundStyle(appearance == .terminal ? Color.green : Color.secondary)
            .disabled(isRefreshing)
            .help("Refresh")
        }
    }
}
