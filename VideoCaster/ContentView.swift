//
//  ContentView.swift
//  VideoCaster
//
//  Created by Harel Zadok on 19/11/2024.
//

import SwiftUI
import AwesomeEnum
import GoogleCast

struct ContentView: View {
    var body: some View {
        TabView {
            Group {
                TelegramScreen()
                    .tabItem {
                        Image(uiImage: Awesome.Brand.telegramPlane.asImage(size: 36))
                        Text("Telegram")
                    }
                    .tag(0)
                VideoListScreen()
                    .tabItem {
                        Image(systemName: "play.tv")
                        Text("Gallery")
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

struct AppPreview: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject({ () -> TelegramManager in
            let envObj = TelegramManager()
            return envObj
        }() )
    }
}
