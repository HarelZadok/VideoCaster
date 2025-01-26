//
//  MessageView.swift
//  VideoCaster
//
//  Created by Harel Zadok on 17/01/2025.
//

import SwiftUI
import TDLibKit

struct TextMessageView: View {
    let text: String
    let isSent: Bool
    let senderId: MessageSender?
    let prevMessageSenderId: MessageSender?
    let nextMessageSenderId: MessageSender?
    let chatId: Int64
    
    init(
        text: String,
        isSent: Bool,
        senderId: MessageSender? = nil,
        prevMessageSenderId: MessageSender? = nil,
        nextMessageSenderId: MessageSender? = nil,
        chatId: Int64 = 0
    ) {
        self.text = text
        self.isSent = isSent
        self.senderId = senderId
        self.chatId = chatId
        self.prevMessageSenderId = prevMessageSenderId
        self.nextMessageSenderId = nextMessageSenderId
    }
    
    init(message: Message) {
        switch message.content {
        case .messageText(let text):
            self.init(text: text.text.text, isSent: message.isOutgoing, senderId: message.senderId, chatId: message.chatId)
        default:
            self.init(text: "NOT SUPPORTED YET!", isSent: message.isOutgoing, senderId: message.senderId, chatId: message.chatId)
        }
    }
    
    var body: some View {
        MessageView(isSent: isSent, senderId: senderId, prevMessageSenderId: prevMessageSenderId, nextMessageSenderId: nextMessageSenderId, chatId: chatId) {
            Text(text)
        }
    }
}

#Preview {
    VStack {
        ScrollView {
            LazyVStack(alignment: .leading) {
                TextMessageView(text: "Hello, how are you?", isSent: false)
                TextMessageView(text: "I'm good! Thanks for asking.", isSent: true)
                TextMessageView(
                    text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
                    isSent: false
                )
                TextMessageView(
                    text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
                    isSent: true
                )
                TextMessageView(text: "Cheers!", isSent: true)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        ChatTextArea(disabled: false)
            .padding()
    }
}
