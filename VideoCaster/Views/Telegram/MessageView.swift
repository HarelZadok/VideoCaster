//
//  MessageView.swift
//  VideoCaster
//
//  Created by Harel Zadok on 17/01/2025.
//

import SwiftUI
import TDLibKit

struct MessageView: View {
    let text: String
    let senderId: MessageSender?
    let chatId: Int64
    let alignment: Alignment
    let backgroundColor: Color?
    let foregorundColor: Color?
    @State var senderName: String?
    @EnvironmentObject var telegramManager: TelegramManager
    
    init(text: String, isSent: Bool, senderId: MessageSender? = nil, chatId: Int64 = 0) {
        self.text = text
        if isSent {
            alignment = .trailing
            backgroundColor = Color(.secondarySystemBackground)
            foregorundColor = nil
            self.senderId = senderId
            self.chatId = chatId
        }
        else {
            alignment = .leading
            backgroundColor = telegramColor
            foregorundColor = .white
            self.senderId = senderId
            self.chatId = chatId
        }
    }
    
    init(message: Message) {
        switch message.content {
        case .messageText(let text):
            self.init(text: text.text.text, isSent: message.isOutgoing, senderId: message.senderId, chatId: message.chatId)
        default:
            self.init(text: "", isSent: message.isOutgoing, senderId: message.senderId, chatId: message.chatId)
        }
    }
    
    @State private var width = 0.0
    
    var body: some View {
        VStack {
            VStack(alignment: alignment.horizontal) {
                if alignment == .leading, let senderName = senderName {
                    Text(senderName)
                        .font(.caption)
                        .foregroundStyle(Color(.systemBackground))
                        .bold()
                        .frame(height: 8, alignment: .leading)
                }
                Text(text)
            }
            .padding(12)
            .background(backgroundColor)
            .foregroundColor(foregorundColor)
            .clipShape(.rect(
                topLeadingRadius: alignment == .leading ? 3 : 12,
                bottomLeadingRadius: 12,
                bottomTrailingRadius: 12,
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
            if chatId < 0, let senderId = senderId {
                Task {
                    switch senderId {
                    case .messageSenderUser(let messageSenderUser):
                        senderName = await telegramManager.getUser(id: messageSenderUser.userId)?.firstName
                    case .messageSenderChat(_):
                        break
                    }
                }
            }
        }
    }
}

#Preview {
    VStack {
        ScrollView {
            LazyVStack(alignment: .leading) {
                MessageView(text: "Hello, how are you?", isSent: false)
                MessageView(text: "I'm good! Thanks for asking.", isSent: true)
                MessageView(
                    text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
                    isSent: false
                )
                MessageView(
                    text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
                    isSent: true
                )
                MessageView(text: "Cheers!", isSent: true)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        ChatTextArea()
            .padding()
    }
}
