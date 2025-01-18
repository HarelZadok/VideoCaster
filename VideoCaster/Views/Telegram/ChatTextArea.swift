//
//  ChatTextArea.swift
//  VideoCaster
//
//  Created by Harel Zadok on 16/01/2025.
//

import SwiftUI

struct ChatTextArea: View {
    @State var message: String = ""
    @FocusState private var isFocused
    
    var body: some View {
        HStack {
            TextField("Message...", text: $message, axis: .vertical)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 20))
                .lineLimit(3)
                .focused($isFocused)
            Button(action: {}) {
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(telegramColor)
            }
        }
        .padding(.horizontal)
        .onTapGesture {
            isFocused = true
        }
    }
}

#Preview {
    VStack {
        ScrollView {
            
        }
        .scrollDismissesKeyboard(.interactively)
        ChatTextArea()
    }
}
