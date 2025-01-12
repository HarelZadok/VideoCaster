//
//  VideoRow.swift
//  VideoCaster
//
//  Created by Harel Zadok on 11/01/2025.
//

import SwiftUI
import GoogleCast
import Photos

struct VideoRow: View {
    let video: Video
    @State private var showError = false
    @State private var isCastModalPresented = false
    
    var body: some View {
        Button(action: {
            castVideo()
        }) {
            HStack {
                if let thumbnail = video.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                        )
                }
                
                VStack(alignment: .center, spacing: 5) {
                    Text(video.url.lastPathComponent)
                        .font(.headline)
                    if let date = video.creationDate {
                        Text("\(date, formatter: dateFormatter)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .alert(isPresented: $showError) {
                    Alert(title: Text("Could not cast video"), message: Text("Please connect to a chromecast device and try again."))
                }
            }
            .padding(.vertical, 5)
        }
    }

    // Date Formatter for Displaying Creation Date
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private func castVideo() {
        guard let currentCastSession = GCKCastContext.sharedInstance().sessionManager.currentCastSession else {
            GCKCastContext.sharedInstance().presentCastDialog()
            return
        }

        // Convert video if necessary
        LocalHTTPServer.shared.convertToMP4IfNeeded(url: video.url) { mp4URL in
            guard let mp4URL = mp4URL else {
                print("Failed to convert video to MP4")
                showError = true
                return
            }

            // Start the local server
            LocalHTTPServer.shared.startServer(withFileAt: mp4URL) { localURL in
                guard let localURL = localURL else {
                    print("Failed to create local URL")
                    showError = true
                    return
                }

                Task {
                    // Fetch video duration
                    let asset = AVAsset(url: video.url)
                    let duration = try await asset.load(.duration)

                    // Create Media Metadata
                    let metadata = GCKMediaMetadata()
                    metadata.setString(video.url.lastPathComponent, forKey: kGCKMetadataKeyTitle)
                    
                    // Use GCKMediaInformationBuilder
                    let mediaInfoBuilder = GCKMediaInformationBuilder(contentURL: localURL)
                    mediaInfoBuilder.streamType = GCKMediaStreamType.none
                    mediaInfoBuilder.contentType = "video/mp4"
                    mediaInfoBuilder.metadata = metadata
                    mediaInfoBuilder.streamDuration = duration.seconds
                    let mediaInfo = mediaInfoBuilder.build()
                    
                    // Cast the video to Chromecast
                    currentCastSession.remoteMediaClient?.loadMedia(mediaInfo)
                    GCKCastContext.sharedInstance().presentDefaultExpandedMediaControls()
                    GCKCastContext.sharedInstance().useDefaultExpandedMediaControls = true
                }
            }
        }
    }
}
