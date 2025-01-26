//
//  TelegramChatsScreen.swift
//  VideoCaster
//
//  Created by Harel Zadok on 15/01/2025.
//

import SwiftUI
import TDLibKit

struct TelegramChatsScreen: View {
    @State private var searchText: String = ""
    @State private var isPreview: Bool
    @State private var chats: [TelegramChat]
    @State private var showLogoutAlert = false
    
    @EnvironmentObject var telegramManager: TelegramManager
    
    init() {
        isPreview = false
        chats = []
    }
    
    init(previewChats: [TelegramChat]) {
        self.isPreview = true
        chats = previewChats
    }
    
    var body: some View {
        VStack {
            if chats.isEmpty {
                Text("No chats available")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(chats) { chat in
                            if chat.id != chats.first?.id && !chat.title.isEmpty {
                                Divider()
                                    .padding(5)
                            }
                            ChatRow(chat: chat)
                                .contentShape(Rectangle())
                        }
                    }
                    .padding(.vertical)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                }
                .background(Color(.systemBackground))
            }
        }
        .refreshable {
            Task {
                await telegramManager.fetchChats()
                chats = telegramManager.chats
            }
        }
        .toolbarBackground(.background, for: .navigationBar)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
        .navigationTitle("Telegram Chats")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showLogoutAlert = true
                }) {
                    Image(systemName: "escape").foregroundStyle(.red)
                }
            }
        }
        .onAppear {
            if isPreview {
                return
            }
            Task {
                await telegramManager.fetchChats()
                chats = telegramManager.chats
            }
        }
        .onChange(of: searchText) { _ in
            if searchText.isEmpty {
                chats = telegramManager.chats
            } else {
                chats = telegramManager.chats.filter {
                    $0.title.lowercased().contains(searchText.lowercased())
                }
            }
        }
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm", role: .destructive) {
                Task {
                    await telegramManager.logout()
                }
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
    }
}

#Preview {
    TelegramChatsScreen(previewChats: [.init(id: 1, title: "1", lastMessage: "Hey", lastMessageSender: "Sason", isOutgoing: false)])
}
