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
    init () {
        setupGoogleCast()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    private func setupGoogleCast() {
        let discoveryCriteria = GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID)
        let options = GCKCastOptions(discoveryCriteria: discoveryCriteria)
        GCKCastContext.setSharedInstanceWith(options)
    }
}
