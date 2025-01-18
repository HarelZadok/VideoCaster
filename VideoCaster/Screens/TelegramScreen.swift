//
//  TelegramScreen.swift
//  VideoCaster
//
//  Created by Harel Zadok on 11/01/2025.
//

import SwiftUI
import TDLibKit

struct TelegramScreen: View {
    @EnvironmentObject var telegramManager: TelegramManager
    
    var body: some View {
        NavigationStack {
            Group {
                if telegramManager.isAuthorized {
                    TelegramChatsScreen()
                }
                else {
                    TelegramLoginScreen()
                }
            }
            .navigationBarItems(trailing: CastButtonView())
        }
    }
}

#Preview {
    TelegramScreen()
}
