//
//  MessageView.swift
//  VideoCaster
//
//  Created by Harel Zadok on 17/01/2025.
//

import SwiftUI
import TDLibKit
import GoogleCast
import Photos

struct VideoMessageView: View {
    let text: String
    let video: TDLibKit.Video?
    let miniThumbnail: Minithumbnail?
    let thumbnail: Thumbnail?
    @State var videoFile: File?
    @State var thumbnailFile: File?
    @State var thumbnailLoaded: Bool = false
    @State var videoLoaded: Bool = false
    @State var downloadProgress: Double = 0
    @State var isDownloading: Bool = false
    @State var isDownloadPaused: Bool = false
    @State var test: String? = nil
    let isSent: Bool
    let senderId: MessageSender?
    let prevMessageSenderId: MessageSender?
    let nextMessageSenderId: MessageSender?
    let chatId: Int64
    let messageId: Int64?
    @EnvironmentObject var telegramManager: TelegramManager
    
    init(
        text: String,
        video: TDLibKit.Video? = nil,
        miniThumbnail: Minithumbnail? = nil,
        thumbnail: Thumbnail? = nil,
        isSent: Bool,
        senderId: MessageSender? = nil,
        prevMessageSenderId: MessageSender? = nil,
        nextMessageSenderId: MessageSender? = nil,
        chatId: Int64 = 0,
        messageId: Int64? = nil
    ) {
        self.text = text
        self.video = video
        self.miniThumbnail = miniThumbnail
        self.thumbnail = thumbnail
        self.isSent = isSent
        self.senderId = senderId
        self.chatId = chatId
        self.prevMessageSenderId = prevMessageSenderId
        self.nextMessageSenderId = nextMessageSenderId
        self.messageId = messageId
    }
    
    init(message: Message) {
        switch message.content {
        case .messageVideo(let msg):
            self.init(text: msg.caption.text, video: msg.video, thumbnail: msg.video.thumbnail, isSent: message.isOutgoing, senderId: message.senderId, chatId: message.chatId)
        default:
            self.init(text: "NOT SUPPORTED YET!", isSent: message.isOutgoing, senderId: message.senderId, chatId: message.chatId)
        }
    }
    
    var body: some View {
        MessageView(
            isSent: isSent,
            senderId: senderId,
            prevMessageSenderId: prevMessageSenderId,
            nextMessageSenderId: nextMessageSenderId,
            chatId: chatId,
            padding: 2,
            insetContent: true
        ) {
            VStack {
                if thumbnailLoaded {
                    ZStack(alignment: .center) {
                        Image(uiImage: UIImage(contentsOfFile: thumbnailFile!.local.path)!)
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: !text.isEmpty ? 12 : 0,
                                bottomTrailingRadius: !text.isEmpty ? 12 : 0,
                                topTrailingRadius: 0
                            ))
                        if !videoLoaded {
                            Color.black.opacity(0.5)
                                .onTapGesture {
                                    Task {
                                        await downloadVideo(streaming: true)
                                        castVideo()
                                    }
                                }
                                .clipShape(.rect(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: !text.isEmpty ? 12 : 0,
                                    bottomTrailingRadius: !text.isEmpty ? 12 : 0,
                                    topTrailingRadius: 0
                                ))
                            if isDownloading {
                                VStack {
                                    ProgressView(value: downloadProgress){
                                    } currentValueLabel: {
                                        Text(String(format: "%.2f%%", downloadProgress * 100))
                                    }
                                    .progressViewStyle(.linear)
                                    HStack {
                                        if !isDownloadPaused {
                                            Button(action: {
                                                telegramManager.pauseDownloadingFile(fileId: videoFile!.id)
                                            }) {
                                                Image(systemName: "pause.circle")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(maxWidth: 35, maxHeight: 35)
                                            }
                                        } else {
                                            Button(action: {
                                                telegramManager.resumeDownloadingFile(fileId: videoFile!.id)
                                            }) {
                                                Image(systemName: "play.circle")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(maxWidth: 35, maxHeight: 35)
                                            }
                                        }
                                        Spacer()
                                        Button(action: {telegramManager.cancelDownloadingFile(fileId: videoFile!.id)}) {
                                            Image(systemName: "trash.circle")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(maxWidth: 35, maxHeight: 35)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            } else {
                                Button(action: {
                                    Task {
                                        await downloadVideo()
                                    }
                                }) {
                                    Image(systemName: "arrow.down.circle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 50, maxHeight: 50)
                                }
                            }
                        } else {
                            Button(action: {
                                castVideo()
                            }) {
                                Image(systemName: "tv.badge.wifi")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 50, maxHeight: 50)
                            }
                        }
                    }
                }
                else {
                    if let miniThumbnail = miniThumbnail {
                        ZStack(alignment: .center) {
                            Image(uiImage: UIImage(data: miniThumbnail.data)!)
                                .resizable()
                                .scaledToFit()
                                .clipShape(.rect(
                                    topLeadingRadius: 0,
                                    bottomLeadingRadius: !text.isEmpty ? 12 : 0,
                                    bottomTrailingRadius: !text.isEmpty ? 12 : 0,
                                    topTrailingRadius: 0
                                ))
                            Color.black.opacity(0.5)
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                    }
                }
                if (!text.isEmpty) {
                    Text(text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
            }
        }
        .onAppear {
            Task {
                let tFile = await telegramManager.downloadFile(fileId: thumbnail?.file.id ?? 0)
                videoFile = await telegramManager.getFile(fileId: video?.video.id ?? -1)
                let temp = try await telegramManager.client?.getMessageLink(chatId: chatId, forAlbum: false, inMessageThread: false, mediaTimestamp: 0, messageId: messageId!)
                DispatchQueue.main.async {
                    test = temp?.link
                    thumbnailFile = tFile
                    thumbnailLoaded = thumbnailFile!.local.isDownloadingCompleted && !thumbnailFile!.local.path.isEmpty
                    videoLoaded = videoFile?.local.isDownloadingCompleted ?? false
                    isDownloading = videoFile?.local.isDownloadingActive ?? false || (videoFile?.local.downloadedSize ?? 0) > 0
                    downloadProgress = Double(videoFile!.local.downloadedSize) / Double(videoFile!.expectedSize)
                    isDownloadPaused = !videoFile!.local.isDownloadingActive && videoFile!.local.downloadedSize > 0
                    
                    videoLoaded = videoFile!.local.isDownloadingCompleted && !videoFile!.local.path.isEmpty
                    if !videoLoaded {
                        telegramManager.fileListener(fileId: videoFile!.id) { file in
                            downloadProgress = Double(file.local.downloadedSize) / Double(file.expectedSize)
                            
                            if file.local.isDownloadingCompleted && !file.local.path.isEmpty {
                                videoLoaded = true
                            }
                            
                            isDownloading = file.local.isDownloadingActive || file.local.downloadedSize > 0
                            isDownloadPaused = !file.local.isDownloadingActive && file.local.downloadedSize > 0
                        }
                    }
                }
            }
        }
    }
    
    private func downloadVideo(streaming: Bool = false) async {
        let limit = Int64(2 * 1024 * 1024)
        if streaming {
            while !(videoFile?.local.isDownloadingCompleted ?? true) {
                videoFile = await telegramManager.downloadFile(
                    fileId: video?.video.id ?? 0,
                    offset: videoFile?.local.downloadOffset ?? 0,
                    limit: limit,
                    async: true
                )
            }
        } else {
            videoFile = await telegramManager.downloadFile(fileId: video?.video.id ?? 0, async: true)
        }
    }
    
    private func castVideo() {
        guard let currentCastSession = GCKCastContext.sharedInstance().sessionManager.currentCastSession else {
            GCKCastContext.sharedInstance().presentCastDialog()
            return
        }
        
        let path = videoFile!.local.path
        let url = URL(fileURLWithPath: path)
        let thumbnail = UIImage(contentsOfFile: thumbnailFile?.local.path ?? "")

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
            }
        }
    }
    
    func saveVideoToPhotoLibrary() -> Void {
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .video, fileURL: URL(fileURLWithPath: videoFile!.local.path), options: nil)
        }) { success, error in
            print("CMON dude", error?.localizedDescription ?? "success")
        }
    }
}
