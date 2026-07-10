import AppKit
import LimitLensCore
import SwiftUI

enum MenuBarStatusImageRenderer {
    private static let height: CGFloat = 18
    private static let ringDiameter: CGFloat = 16
    private static let ringLineWidth: CGFloat = 2.5
    private static let ringGap: CGFloat = 5
    private static let pillHeight: CGFloat = 14
    private static let pillLineWidth: CGFloat = 1.4
    private static let pillMinWidth: CGFloat = 24
    private static let pillHorizontalPadding: CGFloat = 10

    static func size(for status: MenuBarStatusSnapshot) -> NSSize {
        let indicatorCount = max(status.indicators.count, 1)
        if status.menuBarDisplay == .countdowns {
            let pillWidths = status.indicators.map { pillWidth(for: $0) }.reduce(0, +)
            let totalPillWidth = max(pillWidths, pillMinWidth)
            let gaps = CGFloat(max(status.indicators.count - 1, 0)) * ringGap
            return NSSize(width: totalPillWidth + gaps, height: height)
        }
        let width = CGFloat(indicatorCount) * ringDiameter + CGFloat(indicatorCount - 1) * ringGap
        return NSSize(width: width, height: height)
    }

    static func image(for status: MenuBarStatusSnapshot, animationPhase: CGFloat = 0) -> NSImage {
        let size = size(for: status)
        let image = NSImage(size: size)
        image.isTemplate = false
        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = false
        }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        if status.indicators.isEmpty {
            if status.menuBarDisplay == .countdowns {
                drawEmptyStatePill(in: size)
            } else {
                drawEmptyStateRing(in: size)
            }
        } else if status.menuBarDisplay == .countdowns {
            var xOffset: CGFloat = 0
            for indicator in status.indicators {
                let width = pillWidth(for: indicator)
                let center = NSPoint(x: xOffset + width / 2, y: size.height / 2)
                drawCountdownPill(
                    center: center,
                    indicator: indicator,
                    isRefreshing: status.isRefreshing,
                    animationPhase: animationPhase
                )
                xOffset += width + ringGap
            }
        } else {
            for (index, indicator) in status.indicators.enumerated() {
                let x = CGFloat(index) * (ringDiameter + ringGap) + ringDiameter / 2
                let center = NSPoint(x: x, y: size.height / 2)
                drawRing(
                    center: center,
                    indicator: indicator,
                    isRefreshing: status.isRefreshing,
                    hidesProviderNames: status.hidesProviderNames,
                    animationPhase: animationPhase
                )
            }
        }

        return image
    }

    private static func drawEmptyStateRing(in size: NSSize) {
        let center = NSPoint(x: ringDiameter / 2, y: size.height / 2)
        let radius = ringDiameter / 2 - ringLineWidth / 2
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360, clockwise: false)
        track.lineWidth = ringLineWidth
        track.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.30).setStroke()
        track.stroke()
    }

    private static func drawEmptyStatePill(in size: NSSize) {
        let pillRect = NSRect(
            x: 0,
            y: (size.height - pillHeight) / 2,
            width: pillMinWidth,
            height: pillHeight
        )
        let path = NSBezierPath(roundedRect: pillRect, xRadius: pillHeight / 2, yRadius: pillHeight / 2)
        NSColor.white.withAlphaComponent(0.30).setStroke()
        path.lineWidth = pillLineWidth
        path.stroke()
    }

    private static func pillWidth(for indicator: MenuBarProviderIndicator) -> CGFloat {
        max(countdownTextSize(for: indicator.countdownText).width + pillHorizontalPadding, pillMinWidth)
    }

    private static func countdownTextAttributes(color: NSColor = NSColor.white.withAlphaComponent(0.92)) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: color
        ]
    }

    private static func countdownTextSize(for text: String) -> NSSize {
        (text as NSString).size(withAttributes: countdownTextAttributes())
    }

    private static func drawCountdownPill(
        center: NSPoint,
        indicator: MenuBarProviderIndicator,
        isRefreshing: Bool,
        animationPhase: CGFloat
    ) {
        let text = indicator.countdownText
        let textSize = countdownTextSize(for: text)
        let pillWidth = max(textSize.width + pillHorizontalPadding, pillMinWidth)
        let pillRect = NSRect(
            x: center.x - pillWidth / 2,
            y: center.y - pillHeight / 2,
            width: pillWidth,
            height: pillHeight
        )
        let path = NSBezierPath(roundedRect: pillRect, xRadius: pillHeight / 2, yRadius: pillHeight / 2)
        let tint = pillTint(for: indicator)

        tint.withAlphaComponent(0.12).setFill()
        path.fill()

        NSColor.white.withAlphaComponent(0.22).setStroke()
        path.lineWidth = pillLineWidth
        path.stroke()

        let percent = max(0, min(100, indicator.percentUsed ?? 0))
        if percent > 0 && !isRefreshing {
            let progressWidth = pillRect.width * CGFloat(percent / 100)
            let progressRect = NSRect(
                x: pillRect.minX,
                y: pillRect.minY,
                width: progressWidth,
                height: pillRect.height
            )

            NSGraphicsContext.current?.saveGraphicsState()
            defer { NSGraphicsContext.current?.restoreGraphicsState() }

            path.addClip()
            NSBezierPath(rect: progressRect).addClip()

            tint.setStroke()
            path.lineWidth = pillLineWidth + 0.8
            path.stroke()
        }

        if isRefreshing {
            drawRefreshShimmer(in: pillRect, path: path, tint: tint, phase: animationPhase)
        }

        let textColor = secondaryIconTint(for: indicator)?.withAlphaComponent(0.92)
            ?? NSColor.white.withAlphaComponent(0.92)
        (text as NSString).draw(
            at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2),
            withAttributes: countdownTextAttributes(color: textColor)
        )

        let badgeCenter = NSPoint(x: pillRect.maxX, y: pillRect.maxY)
        if case .stale = indicator.state {
            drawBadge(center: badgeCenter, color: .systemOrange, offset: NSPoint(x: -2.5, y: -2.5))
        }
    }

    private static func drawRefreshShimmer(in pillRect: NSRect, path: NSBezierPath, tint: NSColor, phase: CGFloat) {
        NSGraphicsContext.current?.saveGraphicsState()
        defer { NSGraphicsContext.current?.restoreGraphicsState() }

        path.addClip()

        let bandWidth = pillRect.width * 0.7
        let travel = pillRect.width + bandWidth
        let x = pillRect.minX - bandWidth + CGFloat(phase) * travel
        let bandRect = NSRect(x: x, y: pillRect.minY, width: bandWidth, height: pillRect.height)

        guard let gradient = NSGradient(colors: [
            tint.withAlphaComponent(0),
            tint.withAlphaComponent(0.55),
            tint.withAlphaComponent(0)
        ]) else { return }
        gradient.draw(in: bandRect, angle: 0)

        tint.withAlphaComponent(0.18).setStroke()
        path.lineWidth = pillLineWidth + 0.8
        path.stroke()
    }

    private static func pillTint(for indicator: MenuBarProviderIndicator) -> NSColor {
        switch indicator.state {
        case .loading, .unavailable:
            return .systemGray
        case .healthy:
            return lowUsageColor(for: indicator.tab)
        case .warning, .stale:
            return .systemOrange
        case .critical:
            return .systemRed
        }
    }

    private static func lowUsageColor(for tab: ProviderTab) -> NSColor {
        switch tab {
        case .codex:
            return .systemBlue
        case .cursor:
            return .systemPurple
        case .devin:
            return .systemGreen
        case .openCodeGo:
            return .systemIndigo
        case .overview, .settings:
            return .systemGray
        }
    }

    private static func drawRing(
        center: NSPoint,
        indicator: MenuBarProviderIndicator,
        isRefreshing: Bool,
        hidesProviderNames: Bool,
        animationPhase: CGFloat
    ) {
        let radius = ringDiameter / 2 - ringLineWidth / 2
        let track = NSBezierPath()
        track.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        track.lineWidth = ringLineWidth
        track.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.22).setStroke()
        track.stroke()

        switch indicator.state {
        case .loading:
            drawAnimatedFillArc(center: center, radius: radius, indicator: indicator, phase: animationPhase)
            drawProviderIcon(for: indicator.tab, center: center, hidesProviderNames: hidesProviderNames, tint: secondaryIconTint(for: indicator))
        case .unavailable:
            drawUnavailable(center: center, radius: radius)
            drawProviderIcon(for: indicator.tab, center: center, hidesProviderNames: hidesProviderNames, alpha: 0.42, tint: secondaryIconTint(for: indicator))
        case .healthy, .warning, .critical, .stale:
            if isRefreshing {
                drawAnimatedFillArc(center: center, radius: radius, indicator: indicator, phase: animationPhase)
            } else {
                drawProgressArc(center: center, radius: radius, indicator: indicator)
            }
            drawProviderIcon(for: indicator.tab, center: center, hidesProviderNames: hidesProviderNames, tint: secondaryIconTint(for: indicator))
            if case .stale = indicator.state {
                drawBadge(center: center, color: .systemOrange, offset: NSPoint(x: 4.5, y: 4.5))
            }
        }
    }

    private static func drawAnimatedFillArc(
        center: NSPoint,
        radius: CGFloat,
        indicator: MenuBarProviderIndicator,
        phase: CGFloat
    ) {
        // Breathe 0 -> 1 -> 0 so the ring fills with the gradient and empties, looping.
        let triangle = phase < 0.5 ? phase * 2 : 2 - phase * 2
        let fraction = max(0.04, min(1, triangle))
        drawGradientArc(
            center: center,
            radius: radius,
            fraction: fraction,
            colors: lowUsageGradient(for: indicator.tab)
        )
    }

    private static func drawArc(center: NSPoint, radius: CGFloat, fraction: CGFloat, color: NSColor) {
        let clamped = max(0, min(1, fraction))
        guard clamped > 0 else { return }

        let path = NSBezierPath()
        path.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: 90 - 359.9 * clamped,
            clockwise: true
        )
        path.lineWidth = ringLineWidth
        path.lineCapStyle = .round
        color.setStroke()
        path.stroke()
    }

    private static func drawProgressArc(center: NSPoint, radius: CGFloat, indicator: MenuBarProviderIndicator) {
        let percent = max(0, min(100, indicator.percentUsed ?? 0))
        let fraction = CGFloat(percent / 100)
        guard fraction > 0 else { return }

        if percent >= 70 {
            drawArc(center: center, radius: radius, fraction: fraction, color: .systemRed)
        } else if percent >= 50 {
            drawArc(center: center, radius: radius, fraction: fraction, color: .systemOrange)
        } else {
            drawGradientArc(
                center: center,
                radius: radius,
                fraction: fraction,
                colors: lowUsageGradient(for: indicator.tab)
            )
        }
    }

    private static func drawGradientArc(
        center: NSPoint,
        radius: CGFloat,
        fraction: CGFloat,
        colors: (start: NSColor, end: NSColor)
    ) {
        let clamped = max(0, min(1, fraction))
        guard clamped > 0 else { return }

        let segments = max(2, Int(ceil(clamped * 28)))
        for index in 0..<segments {
            let startProgress = clamped * CGFloat(index) / CGFloat(segments)
            let endProgress = clamped * CGFloat(index + 1) / CGFloat(segments)
            let colorProgress = CGFloat(index) / CGFloat(max(segments - 1, 1))
            let color = interpolatedColor(from: colors.start, to: colors.end, progress: colorProgress)

            let path = NSBezierPath()
            path.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: 90 - 359.9 * startProgress,
                endAngle: 90 - 359.9 * endProgress,
                clockwise: true
            )
            path.lineWidth = ringLineWidth
            path.lineCapStyle = .round
            color.setStroke()
            path.stroke()
        }
    }

    private static func drawUnavailable(center: NSPoint, radius: CGFloat) {
        let slash = NSBezierPath()
        slash.move(to: NSPoint(x: center.x - radius * 0.65, y: center.y - radius * 0.65))
        slash.line(to: NSPoint(x: center.x + radius * 0.65, y: center.y + radius * 0.65))
        slash.lineWidth = 1.8
        slash.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.55).setStroke()
        slash.stroke()
    }

    private static func drawBadge(center: NSPoint, color: NSColor, offset: NSPoint) {
        let rect = NSRect(x: center.x + offset.x - 2, y: center.y + offset.y - 2, width: 4, height: 4)
        let badge = NSBezierPath(ovalIn: rect)
        color.setFill()
        badge.fill()
    }

    private static func drawProviderIcon(
        for tab: ProviderTab,
        center: NSPoint,
        hidesProviderNames: Bool,
        alpha: CGFloat = 0.82,
        tint: NSColor? = nil
    ) {
        let iconColor = tint?.withAlphaComponent(alpha) ?? NSColor.white.withAlphaComponent(alpha)
        if tab == .codex && !hidesProviderNames {
            drawPromptIcon(center: center, alpha: alpha, color: iconColor)
            return
        }

        let symbolName = hidesProviderNames ? "circle.grid.2x2" : tab.systemImage
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
            drawFallbackIcon(for: tab, center: center, alpha: alpha, color: iconColor)
            return
        }

        let configuration = NSImage.SymbolConfiguration(pointSize: iconPointSize(for: tab), weight: .bold)
        let configured = symbol.withSymbolConfiguration(configuration) ?? symbol
        let image = tintedImage(configured, color: iconColor)
        let layout = iconLayout(for: tab, hidesProviderNames: hidesProviderNames)
        let rect = NSRect(
            x: center.x - layout.size.width / 2 + layout.offset.x,
            y: center.y - layout.size.height / 2 + layout.offset.y,
            width: layout.size.width,
            height: layout.size.height
        )
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    private static func drawPromptIcon(center: NSPoint, alpha: CGFloat, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 6.2, weight: .bold),
            .foregroundColor: color
        ]
        let attributed = NSAttributedString(string: ">_", attributes: attributes)
        let textSize = attributed.size()
        attributed.draw(at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2))
    }

    private static func drawFallbackIcon(for tab: ProviderTab, center: NSPoint, alpha: CGFloat, color: NSColor) {
        let text: String
        switch tab {
        case .codex:
            text = "C"
        case .cursor:
            text = "↖"
        case .devin:
            text = "D"
        case .openCodeGo:
            text = "</"
        case .overview, .settings:
            text = "S"
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 6.5, weight: .bold),
            .foregroundColor: color
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        attributed.draw(at: NSPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2))
    }

    private static func tintedImage(_ image: NSImage, color: NSColor) -> NSImage {
        let tinted = NSImage(size: image.size)
        tinted.isTemplate = false
        tinted.lockFocus()
        defer {
            tinted.unlockFocus()
            tinted.isTemplate = false
        }

        let rect = NSRect(origin: .zero, size: image.size)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        color.set()
        rect.fill(using: .sourceAtop)
        return tinted
    }

    private static func iconPointSize(for tab: ProviderTab) -> CGFloat {
        switch tab {
        case .cursor:
            return 7
        case .openCodeGo:
            return 6.2
        default:
            return 7.2
        }
    }

    private static func iconLayout(
        for tab: ProviderTab,
        hidesProviderNames: Bool
    ) -> (size: NSSize, offset: NSPoint) {
        if hidesProviderNames {
            return (NSSize(width: 9, height: 9), NSPoint(x: 0, y: 0))
        }

        switch tab {
        case .cursor:
            return (NSSize(width: 8.2, height: 8.2), NSPoint(x: 0.8, y: -0.25))
        case .devin:
            return (NSSize(width: 8.8, height: 8.8), NSPoint(x: 0, y: -0.1))
        case .openCodeGo:
            return (NSSize(width: 9.4, height: 9.4), NSPoint(x: 0, y: 0))
        default:
            return (NSSize(width: 9, height: 9), NSPoint(x: 0, y: 0))
        }
    }

    private static func progressFraction(_ percentUsed: Double?) -> CGFloat {
        CGFloat(max(0, min(100, percentUsed ?? 0)) / 100)
    }

    private static func lowUsageGradient(for tab: ProviderTab) -> (start: NSColor, end: NSColor) {
        switch tab {
        case .codex:
            return (NSColor.systemTeal, NSColor.systemBlue)
        case .cursor:
            return (NSColor.systemPurple, NSColor.systemPink)
        case .devin:
            return (NSColor.systemGreen, NSColor.systemMint)
        case .openCodeGo:
            return (NSColor.systemIndigo, NSColor.systemCyan)
        case .overview, .settings:
            return (NSColor.systemGray, NSColor.systemBlue)
        }
    }

    private static func secondaryIconTint(for indicator: MenuBarProviderIndicator) -> NSColor? {
        guard let percent = indicator.secondaryPercentUsed else { return nil }
        let clamped = max(0, min(100, percent))
        if clamped >= 70 {
            return .systemRed
        } else if clamped >= 50 {
            return .systemYellow
        } else {
            return .systemGreen
        }
    }

    private static func interpolatedColor(from start: NSColor, to end: NSColor, progress: CGFloat) -> NSColor {
        let startRGB = start.usingColorSpace(.deviceRGB) ?? start
        let endRGB = end.usingColorSpace(.deviceRGB) ?? end
        let clamped = max(0, min(1, progress))
        return NSColor(
            calibratedRed: startRGB.redComponent + (endRGB.redComponent - startRGB.redComponent) * clamped,
            green: startRGB.greenComponent + (endRGB.greenComponent - startRGB.greenComponent) * clamped,
            blue: startRGB.blueComponent + (endRGB.blueComponent - startRGB.blueComponent) * clamped,
            alpha: startRGB.alphaComponent + (endRGB.alphaComponent - startRGB.alphaComponent) * clamped
        )
    }
}
