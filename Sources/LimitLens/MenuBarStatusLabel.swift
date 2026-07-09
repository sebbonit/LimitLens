import AppKit
import LimitLensCore
import SwiftUI

struct MenuBarStatusLabel: View {
    let status: MenuBarStatusSnapshot

    @State private var animationPhase: CGFloat = 0

    private static let tickInterval: TimeInterval = 1.0 / 30.0
    private static let fillCycleDuration: TimeInterval = 1.4

    private let tick = Timer.publish(every: tickInterval, on: .main, in: .common).autoconnect()

    var body: some View {
        Image(nsImage: MenuBarStatusImageRenderer.image(for: status, animationPhase: animationPhase))
            .renderingMode(.original)
            .interpolation(.high)
            .frame(
                width: MenuBarStatusImageRenderer.size(for: status).width,
                height: MenuBarStatusImageRenderer.size(for: status).height
            )
            .help(status.helpText)
            .accessibilityLabel(status.accessibilityLabel)
            .onReceive(tick) { _ in
                guard status.isRefreshing else {
                    if animationPhase != 0 { animationPhase = 0 }
                    return
                }
                let step = CGFloat(Self.tickInterval / Self.fillCycleDuration)
                animationPhase = (animationPhase + step).truncatingRemainder(dividingBy: 1)
            }
    }
}
