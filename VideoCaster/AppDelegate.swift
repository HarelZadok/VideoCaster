//
//  AppDelegate.swift
//  VideoCaster
//
//  Created by Harel Zadok on 22/01/2025.
//

import GoogleCast
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    internal var window: UIWindow?
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Optionally, ensure the server continues running
        if LocalHTTPServer.shared.isServerRunning() {
            LocalHTTPServer.shared.beginBackgroundTask(application)
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Optionally, perform any actions when the app comes to foreground
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Ensure the background task is ended
        LocalHTTPServer.shared.endBackgroundTask(application)
    }
}
