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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var telegramManager = TelegramManager()
    
    init () {
        setupGoogleCast()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(telegramManager)
        }
    }
    
    private func setupGoogleCast() {
        let discoveryCriteria = GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID)
        let options = GCKCastOptions(discoveryCriteria: discoveryCriteria)
        GCKCastContext.setSharedInstanceWith(options)
    }
}
