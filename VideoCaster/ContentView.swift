//
//  ContentView.swift
//  VideoCaster
//
//  Created by Harel Zadok on 19/11/2024.
//

import SwiftUI
import AwesomeEnum

struct ContentView: View {
    var body: some View {
        TabView {
            Group {
                VideoListScreen()
                    .tabItem {
                        Image(systemName: "play.tv")
                        Text("Gallery")
                    }
                    .tag(0)
                TelegramScreen()
                    .tabItem {
                        Image(uiImage: Awesome.Brand.telegramPlane.asImage(size: 36))
                        Text("Telegram")
                    }
                    .tag(1)
            }
            .padding(.bottom, 10)
            .toolbarBackground(.background, for: .tabBar)
        }
        .onAppear {
            UITabBar.appearance().clipsToBounds = true
        }
    }
}

#Preview {
    ContentView()
}
