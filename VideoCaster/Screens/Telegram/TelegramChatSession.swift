//
//  TelegramChatSession.swift
//  VideoCaster
//
//  Created by Harel Zadok on 16/01/2025.
//

import SwiftUI
import TDLibKit

struct TelegramChatSession: View {
    private enum Field: Int, CaseIterable {
        case textArea
    }
    
    var chat: SessionChat
    var truncatedTitle: String {
        chat.title.count > 25 ? String(chat.title.prefix(22)) + "..." : chat.title
    }
    
    @State private var messages: [Message] = []
    @State private var isFetchingMessages = false
    @State private var currentMessageId: Int64?
    @State private var keyboardHeight: CGFloat = 0
    @State private var scrollToBottom: () -> Void = { }
    @State private var scrollButtonOffset: CGFloat = -20
    @State private var canSendMessages: Bool = true
    @EnvironmentObject var telegramManager: TelegramManager
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            // Invisible view to scroll to
                            Color.clear
                                .frame(height: 1)
                                .id("Bottom")
                                .onAppear {
                                    withAnimation {
                                        scrollButtonOffset = -20
                                    }
                                }
                                .onDisappear {
                                    withAnimation {
                                        scrollButtonOffset = 22
                                    }
                                }
                                
                            ForEach(Array(messages.enumerated()), id: \.0) { index, message in
                                withAnimation {
                                    buildMessageView(message, index < messages.count - 1 ? messages[index + 1] : nil, index > 0 ? messages[index - 1] : nil)
                                        .flippedUpsideDown()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .flippedUpsideDown()
                    .onAppear {
                        scrollToBottom = {
                            DispatchQueue.main.async {
                                withAnimation {
                                    proxy.scrollTo("Bottom", anchor: .bottom)
                                }
                            }
                        }
                    }
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .onChange(of: messages.count) { _ in
                        scrollToBottom()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    
                    Spacer()
                    
                    ChatTextArea(disabled: !canSendMessages)
                        .onSend { text in
                            await telegramManager.sendMessage(text: text, to: chat.id)
                        }
                }
                Button(action: scrollToBottom) {
                    Image(systemName: "arrow.down")
                        .resizable()
                        .frame(width: 16, height: 20)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .foregroundStyle(.background)
                        .background(telegramColor)
                }
                .clipShape(.circle)
                .buttonStyle(.plain)
                .position(x: geometry.size.width - scrollButtonOffset, y: geometry.size.height - 72)
            }
        }
        .navigationBarItems(trailing: CastButtonView())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(truncatedTitle)
        .toolbarBackground(.background, for: .navigationBar)
        .background(Color(.systemBackground))
        .onAppear {
            telegramManager.onMessageReceived(of: chat.id) { message in
                if message.id != messages.first?.id {
                    messages.insert(message, at: 0)
                }
            }
            
            fetchMessages()
        }
        .onAppear(perform: addKeyboardObservers)
        .onDisappear(perform: removeKeyboardObservers)
        .onChange(of: messages.count) { _ in
            fetchMessages()
        }
        .onAppear {
            Task {
                canSendMessages = (try await telegramManager.client?.getChat(chatId: chat.id))?.permissions.canSendBasicMessages ?? false
            }
        }
    }

    private func addKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { notification in
            keyboardHeight = 0
        }
    }

    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func fetchMessages() {
        guard let client = telegramManager.client else {
            print("Telegram client is not initialized.")
            return
        }
        
        do {
            try client.getChatHistory(
                chatId: chat.id,
                fromMessageId: 0,
                limit: 99,
                offset: 0,
                onlyLocal: false,
                completion: { res in
                    switch res {
                    case .success(let history):
                        DispatchQueue.main.async {
                            if let fetchedMessages = history.messages {
                                messages = fetchedMessages
                            }
                        }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            print("Error fetching chat history: \(error)")
                        }
                    }
                }
            )
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    @ViewBuilder private func buildMessageView(_ message: Message, _ prevMessage: Message?, _ nextMessage: Message?) -> some View {
        switch message.content {
        case .messageText(let msg):
            TextMessageView(
                text: msg.text.text,
                isSent: message.isOutgoing,
                senderId: message.senderId,
                prevMessageSenderId: prevMessage?.senderId,
                nextMessageSenderId: nextMessage?.senderId,
                chatId: message.chatId
            )
                .id(message.id)
        case .messagePhoto(let msg):
            ImageMessageView(
                text: msg.caption.text,
                image: biggestSize(msg.photo.sizes),
                thumbnail: msg.photo.minithumbnail,
                isSent: message.isOutgoing,
                senderId: message.senderId,
                prevMessageSenderId: prevMessage?.senderId,
                nextMessageSenderId: nextMessage?.senderId,
                chatId: message.chatId
            )
                .id(message.id)
        case .messageVideo(let msg):
            VideoMessageView(
                text: msg.caption.text,
                video: msg.video,
                thumbnail: msg.video.thumbnail,
                isSent: message.isOutgoing,
                senderId: message.senderId,
                prevMessageSenderId: prevMessage?.senderId,
                nextMessageSenderId: nextMessage?.senderId,
                chatId: message.chatId,
                messageId: message.id
            )
        case .messageDocument(let msg):
            DocumentMessageView(
                text: msg.caption.text,
                document: msg.document,
                thumbnail: msg.document.thumbnail,
                isSent: message.isOutgoing,
                senderId: message.senderId,
                prevMessageSenderId: prevMessage?.senderId,
                nextMessageSenderId: nextMessage?.senderId,
                chatId: message.chatId,
                messageId: message.id
            )
        default:
            EmptyView()
        }
    }
    
    private func biggestSize(_ sizes: [PhotoSize]) -> PhotoSize {
        var big = sizes[0]
        for i in sizes {
            if big.height < i.height {
                big = i
            }
        }
        
        return big
    }
}

struct FlippedUpsideDown: ViewModifier {
   func body(content: Content) -> some View {
    content
           .rotationEffect(.radians(.pi))
      .scaleEffect(x: -1, y: 1, anchor: .center)
   }
}
extension View{
   func flippedUpsideDown() -> some View{
     self.modifier(FlippedUpsideDown())
   }
}
