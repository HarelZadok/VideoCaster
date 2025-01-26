//
//  MessageView.swift
//  VideoCaster
//
//  Created by Harel Zadok on 17/01/2025.
//

import SwiftUI
import TDLibKit

struct ImageMessageView: View {
    let text: String
    let image: PhotoSize?
    let thumbnail: Minithumbnail?
    @State var imageFile: File?
    @State var imageLoaded: Bool = false
    let isSent: Bool
    let senderId: MessageSender?
    let prevMessageSenderId: MessageSender?
    let nextMessageSenderId: MessageSender?
    let chatId: Int64
    @EnvironmentObject var telegramManager: TelegramManager
    
    init(
        text: String,
        image: PhotoSize? = nil,
        thumbnail: Minithumbnail? = nil,
        isSent: Bool,
        senderId: MessageSender? = nil,
        prevMessageSenderId: MessageSender? = nil,
        nextMessageSenderId: MessageSender? = nil,
        chatId: Int64 = 0
    ) {
        self.text = text
        self.image = image
        self.thumbnail = thumbnail
        self.isSent = isSent
        self.senderId = senderId
        self.chatId = chatId
        self.prevMessageSenderId = prevMessageSenderId
        self.nextMessageSenderId = nextMessageSenderId
    }
    
    init(message: Message) {
        switch message.content {
        case .messagePhoto(let msg):
            self.init(text: msg.caption.text, image: msg.photo.sizes.first!, isSent: message.isOutgoing, senderId: message.senderId, chatId: message.chatId)
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
                if imageLoaded {
                    Image(uiImage: UIImage(contentsOfFile: imageFile!.local.path)!)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: !text.isEmpty ? 12 : 0,
                            bottomTrailingRadius: !text.isEmpty ? 12 : 0,
                            topTrailingRadius: 0
                        ))
                }
                else {
                    if let thumbnail = thumbnail {
                        ZStack(alignment: .center) {
                            Image(uiImage: UIImage(data: thumbnail.data)!)
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
                let file = await telegramManager.downloadFile(fileId: image?.photo.id ?? 0)
                DispatchQueue.main.async {
                    imageFile = file
                    imageLoaded = imageFile!.local.isDownloadingCompleted && !imageFile!.local.path.isEmpty
                }
            }
        }
    }
}
