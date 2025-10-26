import SwiftUI
import RealityKit

struct ImmersiveView: View {

    @Environment(ViewModel.self) var model

    var body: some View {
        RealityView { content in
            content.add(model.setupContentEntity())
        }
    }
}

#Preview {
    ImmersiveView()
        .previewLayout(.sizeThatFits)
}
