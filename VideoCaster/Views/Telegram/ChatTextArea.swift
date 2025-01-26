//
//  ChatTextArea.swift
//  VideoCaster
//
//  Created by Harel Zadok on 16/01/2025.
//

import SwiftUI

struct ChatTextArea: View {
    @State var message: String = ""
    @State var canSend: Bool = false
    let disabled: Bool
    @FocusState private var isFocused
    private var onFocusChange: ((Bool) -> Void)? = nil
    private var onSendClick: ((String) async -> Void)? = nil
    
    init(disabled: Bool) {
        self.disabled = disabled
    }
    
    var body: some View {
        if disabled {
            Text("Sending messages is disabled.")
                .frame(maxWidth: .infinity, maxHeight: 22, alignment: .center)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 20))
                .padding(.horizontal)
                .foregroundStyle(.secondary)
        } else {
            HStack {
                TextField("Message...", text: $message, axis: .vertical)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: 20))
                    .lineLimit(3)
                    .focused($isFocused)
                
                Button(action: {
                    let m = message
                    message = ""
                    Task {
                        await onSendClick?(m)
                    }
                }) {
                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(!canSend ? .gray : telegramColor)
                        .disabled(!canSend)
                        .animation(.easeInOut, value: message.isEmpty)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .onTapGesture {
                isFocused = true
            }
            .onChange(of: isFocused) { f in
                onFocusChange?(f)
            }
            .onChange(of: message) { _ in
                canSend = !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .onAppear {
                canSend = !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }
    
     // Function to set the onFocusChange closure
     func onFocus(perform action: @escaping (Bool) -> Void) -> ChatTextArea {
         var copy = self
         copy.onFocusChange = action
         return copy
     }
    
    func onSend(perform action: @escaping (String) async -> Void) -> ChatTextArea {
        var copy = self
        copy.onSendClick = action
        return copy
    }
}

#Preview {
    VStack {
        ScrollView {
            
        }
        .scrollDismissesKeyboard(.interactively)
        ChatTextArea(disabled: false)
        ChatTextArea(disabled: true)
    }
}
