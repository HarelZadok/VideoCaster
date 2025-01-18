//
//  TelegramChatSession.swift
//  VideoCaster
//
//  Created by Harel Zadok on 16/01/2025.
//

import SwiftUI
import TDLibKit

struct TelegramChatSession: View {
    var chat: SessionChat
    var truncatedTitle: String {
        chat.title.count > 25 ? String(chat.title.prefix(22)) + "..." : chat.title
    }
    @State private var messages: [Message] = []
    @State private var isFetchingMessages = false
    @State private var currentMessageId: Int64?
    @ObservedObject private var keyboard = KeyboardResponder()
    
    @EnvironmentObject var telegramManager: TelegramManager
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(messages.reversed(), id: \.id) { message in
                                MessageView(message: message).id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        proxy.scrollTo(
                            currentMessageId,
                            anchor: .top
                        )
                        currentMessageId = messages.last?.id
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .frame(maxWidth: .infinity)
                ChatTextArea()
            }
            .navigationBarItems(trailing: CastButtonView())
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(truncatedTitle)
            .toolbarBackground(.background, for: .navigationBar)
            .padding(.bottom, keyboard.currentHeight)
            .animation(.easeOut(duration: 0.25), value: keyboard.currentHeight)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .background(Color(.systemBackground))
        .refreshable {
            if isFetchingMessages { return }
            
            isFetchingMessages = true
            try! telegramManager.client?.getChatHistory(
                chatId: chat.id,
                fromMessageId: messages.last?.id ?? 0,
                limit: 50,
                offset: 0,
                onlyLocal: false,
                completion: { res in
                    messages += try! res.get().messages!
                    isFetchingMessages = false
                }
            )
        }
        .onAppear {
            isFetchingMessages = true
            try! telegramManager.client?.getChatHistory(
                chatId: chat.id,
                fromMessageId: 0,
                limit: 50,
                offset: 0,
                onlyLocal: false,
                completion: { res in
                    messages = try! res.get().messages!
                    isFetchingMessages = false
                }
            )
        }
    }
}
