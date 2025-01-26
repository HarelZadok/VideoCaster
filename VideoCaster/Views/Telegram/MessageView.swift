//
//  MessageView.swift
//  VideoCaster
//
//  Created by Harel Zadok on 17/01/2025.
//

import SwiftUI
import TDLibKit

struct MessageView<Content: View>: View {
    let messageSenderId: MessageSender?
    let chatId: Int64
    let alignment: Alignment
    let backgroundColor: Color?
    let foregorundColor: Color?
    let prevMessageSenderId: MessageSender?
    let nextMessageSenderId: MessageSender?
    let padding: CGFloat
    let insetContent: Bool
    @State var senderName: String?
    @State var prevSenderId: Int64?
    @State var senderId: Int64?
    @State var nextSenderId: Int64?
    @EnvironmentObject var telegramManager: TelegramManager
    let content: () -> Content
    
    init(
        isSent: Bool,
        senderId: MessageSender? = nil,
        prevMessageSenderId: MessageSender? = nil,
        nextMessageSenderId: MessageSender? = nil,
        chatId: Int64 = 0,
        padding: CGFloat = 12,
        insetContent: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        if isSent {
            alignment = .trailing
            backgroundColor = Color(.secondarySystemBackground)
            foregorundColor = nil
        }
        else {
            alignment = .leading
            backgroundColor = telegramColor
            foregorundColor = .white
        }
        self.messageSenderId = senderId
        self.chatId = chatId
        self.content = content
        self.prevMessageSenderId = prevMessageSenderId
        self.nextMessageSenderId = nextMessageSenderId
        self.padding = padding
        self.insetContent = insetContent
    }
    
    @State private var width = 0.0
    
    var body: some View {
        VStack {
            VStack {
                VStack(alignment: alignment.horizontal) {
                    if alignment == .leading, prevSenderId != senderId, let senderName = senderName {
                        Text(senderName)
                            .font(.caption)
                            .foregroundStyle(Color(.systemBackground))
                            .bold()
                            .frame(height: 8, alignment: .leading)
                    }
                    content()
                }
                .foregroundColor(foregorundColor)
                .clipShape(
                    insetContent ? .rect(
                        topLeadingRadius: alignment == .leading ? 2 : 10,
                        bottomLeadingRadius: (alignment == .leading && (senderId ?? 0) == nextSenderId) ? 2 : 10,
                        bottomTrailingRadius: (alignment == .trailing && (senderId ?? 0) == nextSenderId) ? 2 : 10,
                        topTrailingRadius: alignment == .trailing ? 2 : 10
                    ) : .rect()
                )
                .padding(padding)
            }
            .background(backgroundColor)
            .clipShape(.rect(
                topLeadingRadius: alignment == .leading ? 3 : 12,
                bottomLeadingRadius: (alignment == .leading && (senderId ?? 0) == nextSenderId) ? 3 : 12,
                bottomTrailingRadius: (alignment == .trailing && (senderId ?? 0) == nextSenderId) ? 3 : 12,
                topTrailingRadius: alignment == .trailing ? 3 : 12
            ))
            .frame(maxWidth: width * 0.85, alignment: alignment)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .background(
            GeometryReader { g in
                DispatchQueue.main.async {
                    self.width = g.size.width
                }
                return Color.clear
            }
        )
        .onAppear {
            if chatId < 0, let messageSenderId = messageSenderId {
                Task {
                    switch messageSenderId {
                    case .messageSenderUser(let messageSenderUser):
                        senderName = await telegramManager.getMessageSenderName(id: messageSenderUser)
                    case .messageSenderChat(_):
                        break
                    }
                }
            }
            Task {
                senderId = await telegramManager.getUserId(messageSenderId)
                prevSenderId = await telegramManager.getUserId(prevMessageSenderId)
                nextSenderId = await telegramManager.getUserId(nextMessageSenderId)
            }
        }
        .padding(.bottom, senderId == nextSenderId ? 0 : 8)
    }
}

#Preview {
    ScrollView {
        LazyVStack(alignment: .leading, spacing: 2) {
            Group {
                TextMessageView(text: "Hello Darkness my old friend", isSent: true, senderId: nil, chatId: 0)
                TextMessageView(text: "Hello Ive come to talk to you again", isSent: false, senderId: nil, chatId: 0)
                TextMessageView(text: "Hello youre creeping me out", isSent: true, senderId: nil, chatId: 0)
                TextMessageView(text: "Hello dude chill the fuck off", isSent: false, senderId: nil, chatId: 0)
                TextMessageView(text: "Hello hahahah delicious whoo hoo", isSent: false, senderId: nil, chatId: 0)
            }
            .flippedUpsideDown()
        }
    }
    .flippedUpsideDown()
    .padding()
    .environmentObject(TelegramManager(phoneNumber: "+972587305151"))
}
