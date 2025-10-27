//
//  PlayerControlsView.swift
//  immersive_video_player
//
//  Created by Gary Wu on 10/26/25.
//

import SwiftUI
import AVKit
internal import Combine

struct PlayerControlsView: View {
    @Environment(AVPlayerViewModel.self) var viewModel
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var isPlaying: Bool = false
    var onDismiss: () -> Void

    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            // Back button
            HStack {
                Button(action: onDismiss) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                        Text("Exit")
                            .font(.headline)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(10)
                }
                Spacer()
            }

            // Time slider
            VStack(spacing: 8) {
                Slider(value: Binding(
                    get: { currentTime },
                    set: { newValue in
                        let time = CMTime(seconds: newValue, preferredTimescale: 600)
                        viewModel.avPlayer.seek(to: time)
                    }
                ), in: 0...max(duration, 0.1))
                .disabled(duration == 0)

                HStack {
                    Text(timeString(from: currentTime))
                        .font(.caption)
                        .monospacedDigit()
                    Spacer()
                    Text(timeString(from: duration))
                        .font(.caption)
                        .monospacedDigit()
                }
            }

            // Playback controls
            HStack(spacing: 32) {
                // Rewind 10s
                Button(action: {
                    let newTime = max(currentTime - 10, 0)
                    viewModel.avPlayer.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
                }) {
                    Image(systemName: "gobackward.10")
                        .font(.title2)
                }

                // Play/Pause
                Button(action: {
                    if isPlaying {
                        viewModel.avPlayer.pause()
                    } else {
                        viewModel.avPlayer.play()
                    }
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                }

                // Forward 10s
                Button(action: {
                    let newTime = min(currentTime + 10, duration)
                    viewModel.avPlayer.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
                }) {
                    Image(systemName: "goforward.10")
                        .font(.title2)
                }
            }
        }
        .padding()
        .frame(width: 500)
        .glassBackgroundEffect()
        .onReceive(timer) { _ in
            updatePlaybackState()
        }
    }

    private func updatePlaybackState() {
        currentTime = viewModel.avPlayer.currentTime().seconds
        isPlaying = viewModel.avPlayer.rate > 0

        if let item = viewModel.avPlayer.currentItem {
            duration = item.duration.seconds
        }
    }

    private func timeString(from timeInterval: TimeInterval) -> String {
        guard timeInterval.isFinite && !timeInterval.isNaN else {
            return "0:00"
        }

        let totalSeconds = Int(timeInterval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    PlayerControlsView(onDismiss: {})
        .environment(AVPlayerViewModel())
}
