import AppKit
import LimitLensCore
import SwiftUI

@main
struct LimitLensApp: App {
    @StateObject private var viewModel = UsageViewModel()

    init() {
        NSApplication.shared.applicationIconImage = LimitLensArtwork.image
    }

    var body: some Scene {
        MenuBarExtra {
            LimitLensPopover(viewModel: viewModel)
                .frame(width: 460)
        } label: {
            MenuBarStatusLabel(status: viewModel.menuBarStatus)
                .task {
                    viewModel.start()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
