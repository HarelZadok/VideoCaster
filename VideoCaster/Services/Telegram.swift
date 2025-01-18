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

    private let databasePath: URL

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
                    let newChat = TelegramChat(id: chat.id, title: chat.title, lastMessage: lastMessage, lastMessageSender: lastMessageSender)
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
            return await getUser(id: user.userId)?.firstName
        case .messageSenderChat(let chat):
            return await getChatName(id: chat.chatId)
        case .none:
            return nil
        }
    }
}
