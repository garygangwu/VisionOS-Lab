//
//  immersive_video_playerApp.swift
//  immersive_video_player
//
//  Created by Gary Wu on 10/26/25.
//

import SwiftUI

@main
struct immersive_video_playerApp: App {

    @State private var appModel = AppModel()
    @State private var avPlayerViewModel = AVPlayerViewModel()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(appModel)
        }
        .defaultSize(width: 400, height: 240)

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .environment(avPlayerViewModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                    avPlayerViewModel.play()
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                    avPlayerViewModel.pause()
                }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
