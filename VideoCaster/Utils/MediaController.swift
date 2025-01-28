//
//  MediaController.swift
//  VideoCaster
//
//  Created by Harel Zadok on 28/01/2025.
//

import Foundation
import MediaPlayer
import AVFoundation
import UIKit

@MainActor
class MediaController: ObservableObject {
    static let shared = MediaController() // Singleton instance
    
    private var silentPlayer: AVAudioPlayer?

    private init() {
        setupAudioSession()
        setupNowPlaying()
        setupRemoteCommands()
        startSilentAudio()
    }

    // Computed property to expose nowPlayingInfo
    var nowPlayingInfo: [String: Any]? {
        return MPNowPlayingInfoCenter.default().nowPlayingInfo
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            print("Audio session activated.")
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    private func setupNowPlaying() {
        let nowPlayingInfo: [String: Any] = [:]

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        print("Now Playing Info initialized.")
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] event in
            self?.handlePlayCommand()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.handlePauseCommand()
            return .success
        }

        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            self?.handleNextTrackCommand()
            return .success
        }

        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            self?.handlePreviousTrackCommand()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.handleSeekCommand(event.positionTime)
            }
            return .success
        }

        // Enable or disable commands as needed
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.isEnabled = true

        print("Remote commands setup completed.")
    }

    // MARK: - Command Handlers

    func handlePlayCommand() {
        print("Play command received.")
        // Implement your play logic here, e.g., send a network request to start playback
        ChromecastManager.shared.play()
        // Update Now Playing Info
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
    }

    func handlePauseCommand() {
        print("Pause command received.")
        // Implement your pause logic here, e.g., send a network request to pause playback
        ChromecastManager.shared.pause()
        // Update Now Playing Info
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
    }

    func handleNextTrackCommand() {
        print("Next track command received.")
        if ChromecastManager.shared.getCurrentTime() + 10 >= ChromecastManager.shared.getDuration() {
            ChromecastManager.shared.seekToEnd()
        } else {
            ChromecastManager.shared.seekToRelative(10)
        }
    }

    func handlePreviousTrackCommand() {
        print("Previous track command received.")
        if ChromecastManager.shared.getCurrentTime() - 10 <= 0 {
            ChromecastManager.shared.seekToStart()
        } else {
            ChromecastManager.shared.seekToRelative(-10)
        }
    }
    
    func handleSeekCommand(_ position: TimeInterval) {
        print(position, ChromecastManager.shared.getDuration())
        ChromecastManager.shared.seekTo(position)
    }

    // MARK: - Update Now Playing Info

    func setVideo(title: String,
                  duration: TimeInterval,
                  thumbnail: UIImage?,
                  url: URL) {
        var nowPlayingInfo: [String: Any] = [:]
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0 // Assuming playback starts immediately
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0

        if let thumbnail = thumbnail {
            let artwork = MPMediaItemArtwork(boundsSize: thumbnail.size) { size in
                return thumbnail
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        // Store the media URL if needed for reference
        nowPlayingInfo["mediaURL"] = url.absoluteString

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        print("Now Playing Info Set: \(nowPlayingInfo)")
    }
    
    func setPlaying(_ play: Bool) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = play ? 1.0 : 0.0
        if play {
            silentPlayer?.play()
        } else {
            silentPlayer?.pause()
        }
    }
    
    func stop() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        silentPlayer?.stop()
        print("Now Playing Info Cleared.")
    }

    func updatePlaybackPosition(to position: TimeInterval) {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        print("Playback position updated to \(position) seconds.")
    }

    // MARK: - Silent Audio Playback

    private func startSilentAudio() {
        guard let url = Bundle.main.url(forResource: "silence", withExtension: "mp3") else {
            print("Silent audio file not found.")
            return
        }

        do {
            silentPlayer = try AVAudioPlayer(contentsOf: url)
            silentPlayer?.numberOfLoops = -1 // Loop indefinitely
            silentPlayer?.volume = 0.0
            silentPlayer?.play()
            print("Silent audio playback started.")
        } catch {
            print("Failed to initialize silent audio player: \(error)")
        }
    }
}
