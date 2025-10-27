//
//  AVPlayerViewModel.swift
//  immersive_video_player
//
//  Created by Gary Wu on 10/26/25.
//

import AVKit

@MainActor
@Observable
class AVPlayerViewModel: NSObject {
    var isPlaying: Bool = false
    var isPaused: Bool = false
    private var avPlayerViewController: AVPlayerViewController?
    var avPlayer = AVPlayer()
    static var lastPausedTime: CMTime = .zero
    private let videoURL: URL? = {
        return Bundle.main.url(forResource: "avatar", withExtension: "mp4")
    }()

    func play() {
        if isPaused {
            // Resume playback
            print("playing lastPausedTime: ", AVPlayerViewModel.lastPausedTime)
            avPlayer.seek(to: AVPlayerViewModel.lastPausedTime, toleranceBefore: .zero, toleranceAfter: .zero)
            avPlayer.play()
            isPaused = false
        } else if !isPlaying, let videoURL {
            // Start new playback
            isPlaying = true
            let item = AVPlayerItem(url: videoURL)
            avPlayer.replaceCurrentItem(with: item)
            print("playing from lastPausedTime: ", AVPlayerViewModel.lastPausedTime)
            avPlayer.seek(to: AVPlayerViewModel.lastPausedTime, toleranceBefore: .zero, toleranceAfter: .zero)
            avPlayer.play()
        }
    }

    func pause() {
        guard isPlaying, !isPaused else { return }
        avPlayer.pause()
        AVPlayerViewModel.lastPausedTime = avPlayer.currentTime()
        isPaused = true
        print("pause at lastPausedTime: ", AVPlayerViewModel.lastPausedTime)
    }
    
    func reset() {
        guard isPlaying else { return }
        isPlaying = false
        avPlayer.replaceCurrentItem(with: nil)
        avPlayerViewController?.delegate = nil
    }
}

extension AVPlayerViewModel: AVPlayerViewControllerDelegate {
    nonisolated func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        Task { @MainActor in
            reset()
        }
    }
}
