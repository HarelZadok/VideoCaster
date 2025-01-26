//
//  VideoListScreen.swift
//  VideoCaster
//
//  Created by Harel Zadok on 11/01/2025.
//

import SwiftUI
import Photos

var isFetching: Bool = false

struct VideoListScreen: View {
    @State private var videos: [Video] = []
    @State private var showingPermissionDeniedAlert = false
    @State private var searchText: String = ""
    @State private var sortBy: String = "creationDate"

    var body: some View {
        let videoList: [Video] = (searchText.isEmpty ? videos : videos.filter { $0.url.absoluteString.localizedCaseInsensitiveContains(searchText) }).sorted {
            sortBy == "creationDate" ? $0.creationDate.timeIntervalSince1970 > $1.creationDate.timeIntervalSince1970 : $0.duration > $1.duration
        }
        
        NavigationStack {
            ScrollView {
                LazyVStack {
                    ForEach(videoList) { video in
                        VideoRow(video: video)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding()
            }
            .refreshable {
                await fetchVideos()
            }
            .navigationTitle("Your Videos")
            .navigationBarItems(leading: ServerButtonView(), trailing: CastButtonView())
            .onAppear {
                checkPhotoLibraryPermission()
            }
            .alert(isPresented: $showingPermissionDeniedAlert) {
                Alert(
                    title: Text("Permission Denied"),
                    message: Text("Please allow access to your photo library in Settings."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .toolbarBackground(.background, for: .navigationBar)
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
        .background(Color(.systemBackground))
    }

    func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus()

        switch status {
        case .authorized, .limited:
            Task {
                if videos.isEmpty {
                    await fetchVideos()
                }
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    Task {
                        if videos.isEmpty {
                            await fetchVideos()
                        }
                    }
                } else {
                    showingPermissionDeniedAlert = true
                }
            }
        default:
            showingPermissionDeniedAlert = true
        }
    }

    func fetchVideos() async {
        if isFetching == true {
            return
        }
        isFetching = true
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: sortBy, ascending: false)]

        let assets = PHAsset.fetchAssets(with: .video, options: fetchOptions)
        
        videos.removeAll()
        
        var index = -1
        assets.enumerateObjects { asset, _, _ in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                index += 1
                if let urlAsset = avAsset as? AVURLAsset {
                    var video = Video(id: asset.localIdentifier, url: urlAsset.url, creationDate: asset.creationDate!, duration: asset.duration)
                    
                    var processedIDs = Set<String>() // Track processed videos to prevent duplicates

                    let cacheKey = asset.localIdentifier
                    
                    if let cachedImage = ThumbnailCache.shared.image(forKey: cacheKey) {
                        if !processedIDs.contains(video.id) {
                            processedIDs.insert(video.id)
                            video.thumbnail = cachedImage
                            self.videos.append(video)
                        }
                    } else {
                        let thumbnailSize = CGSize(width: 1000, height: 1000)
                        
                        let imageRequestOptions = PHImageRequestOptions()
                        imageRequestOptions.deliveryMode = .highQualityFormat
                        imageRequestOptions.resizeMode = .exact
                        imageRequestOptions.isSynchronous = false
                        imageRequestOptions.isNetworkAccessAllowed = true
                        
                        PHImageManager.default().requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFit, options: imageRequestOptions) { image, info in
                            if !processedIDs.contains(video.id) {
                                processedIDs.insert(video.id)
                                if let image = image {
                                    ThumbnailCache.shared.setImage(image, forKey: cacheKey)
                                    video.thumbnail = image
                                }
                                self.videos.append(video)
                            }
                        }
                    }
                }
                
                if index == assets.count - 1 {
                    isFetching = false;
                }
            }
        }
        
        if assets.count == 0 {
            isFetching = false
        }
    }
}

#Preview {
    VideoListScreen()
}
