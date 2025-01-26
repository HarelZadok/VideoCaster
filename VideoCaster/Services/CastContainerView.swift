//
//  CastContainerView.swift
//  VideoCaster
//
//  Created by Harel Zadok on 22/01/2025.
//


import SwiftUI
import GoogleCast

struct CastContainerView<Content: View>: UIViewControllerRepresentable {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeUIViewController(context: Context) -> GCKUICastContainerViewController {
        // Create a UIHostingController with the SwiftUI content
        let hostingController = UIHostingController(rootView: content)
        
        // Create the Cast container controller using Google Cast's factory method
        let castContainerVC = GCKCastContext.sharedInstance().createCastContainerController(for: hostingController)
        
        // Enable mini media controls
        castContainerVC.miniMediaControlsItemEnabled = true
        
        return castContainerVC
    }
    
    func updateUIViewController(_ uiViewController: GCKUICastContainerViewController, context: Context) {
        // Update the view controller if needed
        // For example, update the rootViewController's content
        if let hostingController = uiViewController.contentViewController as? UIHostingController<Content> {
            hostingController.rootView = content
        }
    }
}
