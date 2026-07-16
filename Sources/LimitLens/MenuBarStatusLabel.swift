import AppKit
import LimitLensCore
import SwiftUI

struct MenuBarStatusLabel: View {
    let status: MenuBarStatusSnapshot

    @State private var animationPhase: CGFloat = 0

    private static let tickInterval: TimeInterval = 1.0 / 30.0
    private static let fillCycleDuration: TimeInterval = 1.4

    var body: some View {
        let imageSize = MenuBarStatusImageRenderer.size(for: status)

        Image(nsImage: MenuBarStatusImageRenderer.image(
            for: status,
            animationPhase: animationPhase,
            size: imageSize
        ))
            .renderingMode(.original)
            .interpolation(.high)
            .frame(
                width: imageSize.width,
                height: imageSize.height
            )
            .help(status.helpText)
            .accessibilityLabel(status.accessibilityLabel)
            .task(id: status.isRefreshing) {
                animationPhase = 0
                guard status.isRefreshing else { return }

                while !Task.isCancelled {
                    do {
                        try await Task.sleep(for: .seconds(Self.tickInterval))
                    } catch {
                        return
                    }
                    let step = CGFloat(Self.tickInterval / Self.fillCycleDuration)
                    animationPhase = (animationPhase + step).truncatingRemainder(dividingBy: 1)
                }
            }
    }
}
