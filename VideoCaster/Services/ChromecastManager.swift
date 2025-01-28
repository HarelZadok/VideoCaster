//
//  ChromecastManager.swift
//  VideoCaster
//
//  Created by Harel Zadok on 28/01/2025.
//

import SwiftUI
import Photos
import MediaPlayer
import GoogleCast

@MainActor
class ChromecastManager {
    static let shared = ChromecastManager()
    private var title: String = ""
    private var url: URL?
    
    func setupGoogleCast() {
        let discoveryCriteria = GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID)
        let options = GCKCastOptions(discoveryCriteria: discoveryCriteria)
        options.suspendSessionsWhenBackgrounded = false
        options.physicalVolumeButtonsWillControlDeviceVolume = true
        GCKCastContext.setSharedInstanceWith(options)
    }
    
    func castVideo(withFileAt url: URL, thumbnail: UIImage?) {
        guard let currentCastSession = GCKCastContext.sharedInstance().sessionManager.currentCastSession else {
            GCKCastContext.sharedInstance().presentCastDialog()
            return
        }

        // Start the local server
        LocalHTTPServer.shared.startServer(withFileAt: url, thumbnail: thumbnail) { localURL in
            guard let localURL = localURL else {
                print("Failed to create local URL")
                return
            }

            Task {
                // Fetch video duration
                let asset = AVAsset(url: url)
                let duration = try await asset.load(.duration)

                // Create Media Metadata
                let metadata = GCKMediaMetadata()
                metadata.setString(url.lastPathComponent, forKey: kGCKMetadataKeyTitle)
                metadata.addImage(GCKImage(url: localURL.appendingPathComponent("thumbnail.jpg"), width: 480, height: 360))
                
                // Use GCKMediaInformationBuilder
                let mediaInfoBuilder = GCKMediaInformationBuilder(contentURL: localURL.appendingPathComponent("video.mp4"))
                mediaInfoBuilder.streamType = GCKMediaStreamType.buffered
                mediaInfoBuilder.contentType = "video/mp4"
                mediaInfoBuilder.metadata = metadata
                mediaInfoBuilder.streamDuration = duration.seconds
                let mediaInfo = mediaInfoBuilder.build()
                
                let castStyle = GCKUIStyle.sharedInstance()
                castStyle.castViews.mediaControl.expandedController.backgroundColor = .systemBackground
                castStyle.castViews.mediaControl.sliderSecondaryProgressColor = .secondarySystemBackground
                castStyle.castViews.mediaControl.sliderProgressColor = UIColor(telegramColor)
                castStyle.apply()
                
                // Cast the video to Chromecast
                currentCastSession.remoteMediaClient?.loadMedia(mediaInfo)
                GCKCastContext.sharedInstance().presentDefaultExpandedMediaControls()
                GCKCastContext.sharedInstance().useDefaultExpandedMediaControls = true
                
                self.title = url.lastPathComponent
                self.url = localURL.appendingPathComponent("video.mp4")
                
                MediaController.shared.setVideo(
                    title: url.lastPathComponent,
                    duration: self.getDuration(),
                    thumbnail: thumbnail,
                    url: localURL.appendingPathComponent("video.mp4")
                )
                
                self.updateMediaController()
            }
        }
    }
    
    private func updateMediaController() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            Task {
                if await self.updateMediaControllerTask() {
                    timer.invalidate()
                }
            }
        }
    }
    
    private func updateMediaControllerTask() async -> Bool {
        if !self.isCasting() || self.isFinished() {
            MediaController.shared.stop()
            return true
        }
        
        MediaController.shared.updatePlaybackPosition(to: getCurrentTime())
        MediaController.shared.setPlaying(isPlaying())
        return false
    }
    
    func stopCasting() {
        GCKCastContext.sharedInstance().sessionManager.endSessionAndStopCasting(true)
    }
    
    func isCasting() -> Bool {
        return GCKCastContext.sharedInstance().sessionManager.hasConnectedCastSession()
    }
    
    func pause() {
        GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient?.pause()
    }
    
    func play() {
        GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient?.play()
        updateMediaController()
    }
    
    func isPlaying() -> Bool {
        guard let mediaStatus = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient?.mediaStatus else {
            return false
        }
        return mediaStatus.playerState == .playing
    }
    
    func isPaused() -> Bool {
        guard let mediaStatus = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient?.mediaStatus else {
            return false
        }
        return mediaStatus.playerState == .paused
    }
    
    func isIdle() -> Bool {
        guard let mediaStatus = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient?.mediaStatus else {
            return false
        }
        return mediaStatus.playerState == .idle
    }
    
    func isFinished() -> Bool {
        return getCurrentTime() >= getDuration()
    }
    
    func isBuffering() -> Bool {
        guard let mediaStatus = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient?.mediaStatus else {
            return false
        }
        return mediaStatus.playerState == .buffering
    }
    
    func getCurrentTime() -> Double {
        guard let mediaClient = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient else {
            return 0
        }
        return Double(mediaClient.approximateStreamPosition())
    }
    
    func getCurrentTimeInt() -> Int {
        guard let mediaClient = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient else {
            return 0
        }
        return Int(mediaClient.approximateStreamPosition())
    }
    
    func seekTo(_ time: Double) {
        let options = GCKMediaSeekOptions()
        options.interval = .init(floatLiteral: time)
        GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient?.seek(with: options)
    }
    
    func seekToRelative(_ time: Double) {
        let options = GCKMediaSeekOptions()
        options.interval = .init(floatLiteral: time)
        options.relative = true
        GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient?.seek(with: options)
    }
    
    func seekToEnd() {
        let options = GCKMediaSeekOptions()
        options.seekToInfinite = true
        GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient?.seek(with: options)
    }
    
    func seekToStart() {
        let options = GCKMediaSeekOptions()
        options.interval = .init(floatLiteral: 0)
        GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient?.seek(with: options)
    }
    
    func setVolume(_ volume: Float) {
        GCKCastContext.sharedInstance().sessionManager.currentCastSession?.setDeviceVolume(volume)
    }
    
    func showFullScreenUI() {
        GCKCastContext.sharedInstance().presentDefaultExpandedMediaControls()
    }
    
    func getDuration() -> Double {
        guard let duration = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient?.mediaStatus?.mediaInformation?.streamDuration
        else {
            return 0
        }
        return Double(duration)
    }
    
    func getLength() -> Double {
        return getDuration()
    }
    
    func getURL() -> URL? {
        return url
    }
    
    func isLivestream() -> Bool {
        guard let isLive = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient?.isPlayingLiveStream
        else {
            return false
        }
        return isLive
    }
    
    func getTitle() -> String {
        return title
    }
}
