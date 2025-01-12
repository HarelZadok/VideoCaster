//
//  CastButtonView.swift
//  VideoCaster
//
//  Created by Harel Zadok on 11/01/2025.
//

import SwiftUI
import GoogleCast

struct CastButtonView: UIViewRepresentable {
    func makeUIView(context: Context) -> GCKUICastButton {
        let castButton = GCKUICastButton(frame: .zero)
        return castButton
    }

    func updateUIView(_ uiView: GCKUICastButton, context: Context) {
        
    }
}

#Preview {
    CastButtonView()
}
