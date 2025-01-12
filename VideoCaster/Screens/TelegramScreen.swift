//
//  TelegramScreen.swift
//  VideoCaster
//
//  Created by Harel Zadok on 11/01/2025.
//

import SwiftUI

struct TelegramScreen: View {
    var body: some View {
        NavigationView {
            Text("Coming soon")
                .navigationTitle("Telegram Videos")
                .navigationBarItems(leading: ServerButtonView(), trailing: CastButtonView())
        }
    }
}

#Preview {
    TelegramScreen()
}
