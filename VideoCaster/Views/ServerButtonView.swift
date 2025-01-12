//
//  ServerButtonView.swift
//  VideoCaster
//
//  Created by Harel Zadok on 11/01/2025.
//

import SwiftUI

struct ServerButtonView: View {
    @State private var isServerRunning: Bool = false
    
    var body: some View {
        Button(action: {
            if isServerRunning {
                LocalHTTPServer.shared.stopServer()
            } else {
                LocalHTTPServer.shared.startServer() { url in }
            }
        }) {
            Image(systemName: "server.rack")
                .foregroundStyle(isServerRunning ? .green : .red )
        }
        .onAppear {
            LocalHTTPServer.shared.onServerStateChange { isRunning in
                isServerRunning = isRunning
            }
        }
    }
}
