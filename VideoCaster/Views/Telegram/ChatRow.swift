//
//  ChatRow.swift
//  VideoCaster
//
//  Created by Harel Zadok on 16/01/2025.
//

import SwiftUI

struct ChatRow: View {
    let chat: TelegramChat
    @State private var sessionChat: SessionChat?
    
    @EnvironmentObject var telegramManager: TelegramManager
    
    var body: some View {
        if chat.title.isEmpty {
            EmptyView()
        }
        else {
            NavigationLink {
                if let sessionChat = sessionChat {
                    TelegramChatSession(chat: sessionChat)
                }
            } label: {
                HStack {
                    VStack {
                        Text(chat.title)
                            .foregroundStyle(telegramColor)
                            .font(.headline)
                            .padding(.bottom, 4)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                        if let lastSender = chat.lastMessageSender, let lastMessage = chat.lastMessage {
                            HStack(spacing: 0) {
                                Text(lastSender)
                                    .foregroundStyle(telegramColor)
                                    .padding(.bottom, 4)
                                    .lineLimit(1)
                                    .padding(.horizontal, 0)
                                Text(": ")
                                    .foregroundStyle(telegramColor)
                                    .padding(.bottom, 4)
                                    .lineLimit(1)
                                    .padding(.horizontal, 0)
                                Text(lastMessage)
                                    .foregroundStyle(.secondary)
                                    .padding(.bottom, 4)
                                    .lineLimit(1)
                                    .padding(.horizontal, 0)
                            }
                        } else {
                            Text("")
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 4)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
                .onAppear {
                    if sessionChat != nil { return }
                    Task {
                        if let name = await telegramManager.getChatName(id: chat.id) {
                            sessionChat = SessionChat(id: chat.id, title: name)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ChatRow(
        chat: TelegramChat(id: 12631, title: "Chat title.", lastMessage: "Hello, World!", lastMessageSender: "Sason")
    )
}
