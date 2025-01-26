//
//  Telegram.swift
//  VideoCaster
//
//  Created by Harel Zadok on 15/01/2025.
//

@preconcurrency import TDLibKit
import SwiftUI

struct TelegramChat: Identifiable {
    let id: Int64
    let title: String
    let lastMessage: String?
    let lastMessageSender: String?
    let isOutgoing: Bool
}

struct SessionChat: Identifiable {
    let id: Int64
    let title: String
}

class TelegramManager: ObservableObject {
    let clientManager = TDLibClientManager()
    @Published var client: TDLibClient?
    @Published var isAuthorized = false
    @Published var authorizationState: AuthorizationState?
    @Published var chats: [TelegramChat] = []
    
    private var currentChatId: Int64? = nil
    private var onMessageUpdate: ((Message) -> Void)? = nil

    private let databasePath: URL
    
    private var fileUpdateFunctions: [Int : (File) -> Void] = [:]

    init() {
        self.databasePath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("tdlib")
        initializeClient()
    }
    
    init(phoneNumber: String) {
        self.databasePath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("tdlib")
        UserDefaults.standard.set(phoneNumber, forKey: "telegramPhoneNumber")
        initializeClient()
    }

    private func initializeClient() {
        createDatabaseDirectoryIfNeeded()
        
        client = clientManager.createClient { [weak self] data, client in
            do {
                let update = try client.decoder.decode(Update.self, from: data)
                DispatchQueue.main.async {
                    if case let .updateAuthorizationState(state) = update {
                        self?.authorizationState = state.authorizationState
                        if state.authorizationState == .authorizationStateReady {
                            self?.isAuthorized = true
                        }
                    }
                    switch update {
                    case .updateNewMessage(let message):
                        if let chatId = self?.currentChatId {
                            if message.message.chatId == chatId {
                                self?.onMessageUpdate?(message.message)
                            }
                        }
                    case .updateFile(let msg):
                        self?.fileUpdateFunctions[msg.file.id]?(msg.file)
                    default:
                        break
                    }
                }
            } catch {
                print("Error decoding update: \(error)")
            }
        }
        
        // Reuse phone number if available
        if let savedPhoneNumber = UserDefaults.standard.string(forKey: "telegramPhoneNumber") {
            Task {
                do {
                    try await setPhoneNumber(savedPhoneNumber)
                } catch {
                    print("Error reusing phone number: \(error)")
                }
            }
        }
    }
    
    private func createDatabaseDirectoryIfNeeded() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: databasePath.path) {
            do {
                try fileManager.createDirectory(at: databasePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating database directory: \(error)")
            }
        }
    }
    
    func onMessageReceived(of chatId: Int64, perform action: @escaping (Message) -> Void) {
        currentChatId = chatId
        onMessageUpdate = action
    }

    func setPhoneNumber(_ phoneNumber: String) async throws {
        guard let client = client else { return }

        try await client.setTdlibParameters(
            apiHash: "bc34270afb5538750bda83a4d9f92b1d",
            apiId: 29453521,
            applicationVersion: "1.0",
            databaseDirectory: databasePath.path,
            databaseEncryptionKey: nil,
            deviceModel: UIDevice.current.name,
            filesDirectory: "",
            systemLanguageCode: Locale.current.identifier,
            systemVersion: UIDevice.current.systemVersion,
            useChatInfoDatabase: true,
            useFileDatabase: true,
            useMessageDatabase: true,
            useSecretChats: true,
            useTestDc: false
        )

        try await client.setAuthenticationPhoneNumber(
            phoneNumber: phoneNumber,
            settings: nil
        )
    }

    func sendAuthenticationCode(_ code: String) async throws {
        guard let client = client else { return }
        try await client.checkAuthenticationCode(code: code)
    }

    @MainActor
    func fetchChats() async {
        self.chats = []

        guard let client = client else { return }
        do {
            let result = try await client.getChats(chatList: nil, limit: 50)
            for chatId in result.chatIds {
                if let chat = try? await client.getChat(chatId: chatId) {
                    var lastMessage: String? = nil
                    var lastMessageSender: String? = nil
                    switch chat.lastMessage?.content {
                    case .messageText(let text):
                        lastMessage = text.text.text
                        lastMessageSender = await getMessageSenderName(id: chat.lastMessage?.senderId)
                    default:
                        break
                    }
                    let newChat = TelegramChat(id: chat.id, title: chat.title, lastMessage: lastMessage, lastMessageSender: lastMessageSender, isOutgoing: chat.lastMessage?.isOutgoing ?? false)
                    if !self.chats.contains(where: { $0.id == chat.id }) {
                        self.chats.append(newChat)
                    }
                }
            }
        } catch {
            print("Error fetching chats: \(error)")
        }
    }

    @MainActor
    func logout() async {
        guard let client = client else { return }
        do {
            try await client.logOut()
            self.chats = []
            self.isAuthorized = false
            UserDefaults.standard.removeObject(forKey: "telegramPhoneNumber")
        } catch {
            print("Error logging out: \(error)")
        }
    }
    
    func getChatName(id: Int64) async -> String? {
        guard let chat = try? await client!.getChat(chatId: id) else { return nil }
        return chat.title
    }
    
    func getUser(id: Int64) async -> User? {
        return try! await client!.getUser(userId: id)
    }
    
    func getMessageSenderName(id: MessageSender?) async -> String? {
        switch id {
        case .messageSenderUser(let user):
            return await getMessageSenderName(id: user)
        case .messageSenderChat(let chat):
            return await getChatName(id: chat.chatId)
        case .none:
            return nil
        }
    }
    
    func getMessageSenderName(id: MessageSenderUser?) async -> String? {
        if let id = id {
            if let userInfo = await getUser(id: id.userId) {
                return userInfo.firstName + " " + userInfo.lastName
            }
        }
        return nil
    }
    
    func getUserId(_ id: MessageSender?) async -> Int64? {
        if case .messageSenderUser(let user)? = id {
            return await getUserId(user)
        }
        if case .messageSenderChat(let chat)? = id {
            return await getChatId(chat)
        }
        return nil
    }
    
    func getUserId(_ id: MessageSenderUser?) async -> Int64? {
        return id?.userId
    }
    
    func getChatId(_ id: MessageSenderChat?) async -> Int64? {
        return id?.chatId
    }
    
    @discardableResult func sendMessage(text: String, to chatId: Int64) async -> Message? {
        do {
            return try await client!.sendMessage(
                chatId: chatId,
                inputMessageContent: .inputMessageText(.init(clearDraft: false, linkPreviewOptions: nil, text: .init(entities: [], text: text))),
                messageThreadId: nil,
                options: nil,
                replyMarkup: nil,
                replyTo: nil
            )
        } catch {
            return nil
        }
    }
    
    func downloadFile(fileId: Int, offset: Int64 = 0, limit: Int64 = 0, async: Bool = false) async -> File? {
        do {
            let file = try await client?.downloadFile(
                fileId: fileId,
                limit: limit,
                offset: offset,
                priority: 1,
                synchronous: !async
            )
            
            return file
        } catch {
            print("Failed to download image.")
        }
        
        return nil
    }
    
    func getFile(fileId: Int) async -> File? {
        return try? await client?.getFile(fileId: fileId)
    }
    
    func pauseDownloadingFile(fileId: Int) {
        Task {
            try await client?.cancelDownloadFile(fileId: fileId, onlyIfPending: false)
        }
    }
    
    func resumeDownloadingFile(fileId: Int) {
        Task {
            await downloadFile(fileId: fileId, async: true)
        }
    }
    
    func cancelDownloadingFile(fileId: Int) {
        Task {
            try await client?.cancelDownloadFile(fileId: fileId, onlyIfPending: false)
            try await client?.deleteFile(fileId: fileId)
        }
    }
    
    func fileListener(fileId: Int, perform action: @escaping (File) -> Void) {
        fileUpdateFunctions[fileId] = action
    }
}
