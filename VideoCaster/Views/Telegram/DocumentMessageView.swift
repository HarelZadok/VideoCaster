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

struct DocumentMessageView: View {
    let text: String
    let document: Document?
    let miniThumbnail: Minithumbnail?
    let thumbnail: Thumbnail?
    @State var documentFile: File?
    @State var thumbnailFile: File?
    @State var thumbnailLoaded: Bool = false
    @State var documentLoaded: Bool = false
    @State var downloadProgress: Double = 0
    @State var isDownloading: Bool = false
    @State var isDownloadPaused: Bool = false
    let isSent: Bool
    let senderId: MessageSender?
    let prevMessageSenderId: MessageSender?
    let nextMessageSenderId: MessageSender?
    let chatId: Int64
    let messageId: Int64?
    @EnvironmentObject var telegramManager: TelegramManager
    
    init(
        text: String,
        document: Document? = nil,
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
        self.document = document
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
        case .messageDocument(let msg):
            self.init(text: msg.caption.text, document: msg.document, thumbnail: msg.document.thumbnail, isSent: message.isOutgoing, senderId: message.senderId, chatId: message.chatId)
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
                ZStack(alignment: .center) {
                    if thumbnailLoaded {
                        Image(uiImage: UIImage(contentsOfFile: thumbnailFile!.local.path)!)
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: !text.isEmpty ? 12 : 0,
                                bottomTrailingRadius: !text.isEmpty ? 12 : 0,
                                topTrailingRadius: 0
                            ))
                        Color.black.opacity(0.5)
                            .clipShape(.rect(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: !text.isEmpty ? 12 : 0,
                                bottomTrailingRadius: !text.isEmpty ? 12 : 0,
                                topTrailingRadius: 0
                            ))
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
                    HStack {
                        if !thumbnailLoaded {
                            Image(systemName: "document.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50, alignment: .leading)
                                .padding(.vertical, 8)
                        }
                        if !documentLoaded {
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
                                                telegramManager.pauseDownloadingFile(fileId: documentFile!.id)
                                            }) {
                                                Image(systemName: "pause.circle")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(maxWidth: 35, maxHeight: 35)
                                            }
                                        } else {
                                            Button(action: {
                                                telegramManager.resumeDownloadingFile(fileId: documentFile!.id)
                                            }) {
                                                Image(systemName: "play.circle")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(maxWidth: 35, maxHeight: 35)
                                            }
                                        }
                                        Spacer()
                                        Button(action: {telegramManager.cancelDownloadingFile(fileId: documentFile!.id)}) {
                                            Image(systemName: "trash.circle")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(maxWidth: 35, maxHeight: 35)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            } else {
                                HStack {
                                    Text(document!.fileName)
                                    Spacer()
                                    Button(action: {
                                        Task {
                                            await downloadDocument()
                                        }
                                    }) {
                                        Image(systemName: "arrow.down.circle")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: 50, maxHeight: 50)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            HStack {
                                Text(document!.fileName)
                                Spacer()
                                Button(action: {
                                    castVideo()
                                }) {
                                    Image(systemName: "tv.badge.wifi")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 50, maxHeight: 50)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 8)
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
                documentFile = await telegramManager.getFile(fileId: document?.document.id ?? -1)
                DispatchQueue.main.async {
                    thumbnailFile = tFile
                    if let thumbnailFile = thumbnailFile {
                        thumbnailLoaded = thumbnailFile.local.isDownloadingCompleted && !thumbnailFile.local.path.isEmpty
                    }
                    if !documentFile!.local.path.isEmpty && FileManager().fileExists(atPath: documentFile!.local.path) {
                        isDownloading = documentFile!.local.isDownloadingActive || documentFile!.local.downloadedSize > 0
                        downloadProgress = Double(documentFile!.local.downloadedSize) / Double(documentFile!.expectedSize)
                        isDownloadPaused = !documentFile!.local.isDownloadingActive && documentFile!.local.downloadedSize > 0
                        documentLoaded = documentFile!.local.isDownloadingCompleted && !documentFile!.local.path.isEmpty
                    }
                    if !documentLoaded {
                        telegramManager.fileListener(fileId: documentFile!.id) { file in
                            downloadProgress = Double(file.local.downloadedSize) / Double(file.expectedSize)
                            
                            if file.local.isDownloadingCompleted && !file.local.path.isEmpty {
                                documentFile = file
                                documentLoaded = true
                            }
                            
                            isDownloading = file.local.isDownloadingActive || file.local.downloadedSize > 0
                            isDownloadPaused = !file.local.isDownloadingActive && file.local.downloadedSize > 0
                        }
                    }
                }
            }
        }
    }
    
    private func downloadDocument(streaming: Bool = false) async {
        let limit = Int64(2 * 1024 * 1024)
        if streaming {
            while !(documentFile?.local.isDownloadingCompleted ?? true) {
                documentFile = await telegramManager.downloadFile(
                    fileId: document?.document.id ?? 0,
                    offset: documentFile?.local.downloadOffset ?? 0,
                    limit: limit,
                    async: true
                )
            }
        } else {
            documentFile = await telegramManager.downloadFile(fileId: document?.document.id ?? 0, async: true)
        }
    }
    
    private func castVideo() {
        let path = documentFile!.local.path
        let url = URL(fileURLWithPath: path)
        let thumbnail = UIImage(contentsOfFile: thumbnailFile?.local.path ?? "")
        
        ChromecastManager.castVideo(withFileAt: url, thumbnail: thumbnail)
    }
}
