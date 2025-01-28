//
//  VideoCasterApp.swift
//  VideoCaster
//
//  Created by Harel Zadok on 20/11/2024.
//

import SwiftUI
import GoogleCast

@main
struct VideoCasterApp: App {
    var telegramManager = TelegramManager()
    @Environment(\.scenePhase) var scenePhase
    
    init () {
        ChromecastManager.setupGoogleCast()
        AudioSessionManager.shared.configureAudioSession()
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(telegramManager)
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                LocalHTTPServer.shared.endBackgroundTask()
                AudioSessionManager.shared.stopSilentAudio()
            case .background:
                LocalHTTPServer.shared.beginBackgroundTask()
                AudioSessionManager.shared.startSilentAudio()
            default:
                break
            }
        }
    }
}
