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
                                Group {
                                    Text(chat.isOutgoing ? "You" : lastSender)
                                        .foregroundStyle(telegramColor)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .bold()
                                        .frame(maxWidth: 100, alignment: .leading)
                                        .fixedSize()
                                    Text(":")
                                        .foregroundStyle(telegramColor)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .bold()
                                        .padding(.leading, 0)
                                        .padding(.trailing, 6)
                                    Text(lastMessage)
                                        .foregroundStyle(Color(.secondaryLabel))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .padding(.horizontal, 0)
                            }
                            .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
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
        chat: TelegramChat(id: 12631, title: "Chat title.", lastMessage: "Hello, World!", lastMessageSender: "Sason", isOutgoing: false)
    )
}
