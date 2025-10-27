//
//  ContentView.swift
//  immersive_video_player
//
//  Created by Gary Wu on 10/26/25.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(AppModel.self) var appModel
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.dismissWindow) var dismissWindow

    var body: some View {
        VStack(spacing: 20) {
            Button(action: {
                Task {
                    if appModel.immersiveSpaceState == .closed {
                        await openImmersiveSpace(id: appModel.immersiveSpaceID)
                        dismissWindow(id: "main")
                    }
                }
            }){
                Text("Play 3D video")
                    .font(.title2)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
