import SwiftUI

@main
struct google_street_viewApp: App {
    @State private var viewModel = ViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
        }
        .windowStyle(.plain)
        .defaultSize(width: 240, height: 300)

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
                .environment(viewModel)
        }
    }
}
