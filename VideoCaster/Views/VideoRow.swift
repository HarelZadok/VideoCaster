//
//  VideoRow.swift
//  VideoCaster
//
//  Created by Harel Zadok on 11/01/2025.
//

import SwiftUI
import GoogleCast
import Photos

struct VideoRow: View {
    let video: Video
    @State private var isCastModalPresented = false
    
    var body: some View {
        Button(action: {
            castVideo()
        }) {
            HStack {
                if let thumbnail = video.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                        )
                }
                
                VStack(alignment: .center, spacing: 5) {
                    Text(video.url.lastPathComponent)
                        .font(.headline)
                    let date = video.creationDate
                    Text("\(date, formatter: dateFormatter)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, 5)
        }
    }

    // Date Formatter for Displaying Creation Date
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private func castVideo() {
        ChromecastManager.shared.castVideo(withFileAt: video.url, thumbnail: video.thumbnail)
    }
}
