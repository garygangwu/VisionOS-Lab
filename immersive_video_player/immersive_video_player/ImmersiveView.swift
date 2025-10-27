//
//  ImmersiveView.swift
//  immersive_video_player
//
//  Created by Gary Wu on 10/26/25.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    @Environment(AVPlayerViewModel.self) var avPlayerViewModel
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.openWindow) var openWindow

    var body: some View {
        RealityView { content, attachments in
            await setupImmersiveVideoPlayer(content: content, attachments: attachments)
        } attachments: {
            Attachment(id: "controls") {
                PlayerControlsView(onDismiss: {
                    Task {
                        await dismissImmersiveSpace()
                        openWindow(id: "main")
                    }
                })
                .environment(avPlayerViewModel)
            }
        }
    }

    @MainActor
    private func setupImmersiveVideoPlayer(content: RealityViewContent, attachments: RealityViewAttachments) async {
        // Create a large sphere for 360-degree video
        let sphere = MeshResource.generateSphere(radius: 10)

        // Create video material
        let videoPlayer = avPlayerViewModel.avPlayer
        let videoMaterial = VideoMaterial(avPlayer: videoPlayer)

        // Create entity with video material
        let videoEntity = ModelEntity(mesh: sphere, materials: [videoMaterial])

        // Flip the sphere inside-out for 360-degree viewing
        videoEntity.scale = SIMD3<Float>(x: -1, y: 1, z: 1)

        // Position the entity
        videoEntity.position = SIMD3<Float>(0, 0, 0)

        content.add(videoEntity)

        // Add controls attachment in front of the user
        if let controlsAttachment = attachments.entity(for: "controls") {
            // Position controls in front of and at eye level
            controlsAttachment.position = SIMD3<Float>(0, 1, -1.5)

            // Ensure the controls face the user (no rotation needed if already facing forward)
            content.add(controlsAttachment)
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
