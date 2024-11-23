///
//  ContentView.swift
//  VideoCaster
//
//  Created by Harel Zadok on 19/11/2024.
//

import SwiftUI
import Photos
import GoogleCast
import GCDWebServer
import ffmpegkit
import MediaPlayer

struct Video: Identifiable {
    let id: String
    let url: URL
    let creationDate: Date?
    var thumbnail: UIImage? // Added thumbnail property
}

class ThumbnailCache {
    static let shared = ThumbnailCache()
    private init() {}
    
    private var cache = NSCache<NSString, UIImage>()
    
    func image(forKey key: String) -> UIImage? {
        return cache.object(forKey: NSString(string: key))
    }
    
    func setImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: NSString(string: key))
    }
}

struct ContentView: View {
    @State private var videos: [Video] = []
    @State private var showingPermissionDeniedAlert = false
    @State private var isServerRunning: Bool
        
    init() {
        isServerRunning = false
    }

    var body: some View {
        NavigationView {
            List(videos) { video in
                VideoRow(video: video)
            }
            .navigationTitle("Your Videos")
            .navigationBarItems(
                leading: Button(action: {
                    if isServerRunning {
                        LocalHTTPServer.shared.stopServer()
                    } else {
                        LocalHTTPServer.shared.startServer() { url in }
                    }
                }) {
                    Image(systemName: "server.rack")
                        .foregroundStyle(isServerRunning ? .green : .red )
                },
                trailing: CastButtonView()
                    .frame(width: 44, height: 44) // Standard Cast button size
            )
            .onAppear {
                checkPhotoLibraryPermission()
                LocalHTTPServer.shared.isRunningListener = $isServerRunning
            }
            .onDisappear {
                videos.removeAll()
            }
            .alert(isPresented: $showingPermissionDeniedAlert) {
                Alert(
                    title: Text("Permission Denied"),
                    message: Text("Please allow access to your photo library in Settings."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus()

        switch status {
        case .authorized, .limited:
            fetchVideos()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    fetchVideos()
                } else {
                    showingPermissionDeniedAlert = true
                }
            }
        default:
            showingPermissionDeniedAlert = true
        }
    }

    func fetchVideos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let assets = PHAsset.fetchAssets(with: .video, options: fetchOptions)

        let dispatchGroup = DispatchGroup()

        assets.enumerateObjects { asset, _, _ in
            dispatchGroup.enter()
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    var video = Video(id: asset.localIdentifier, url: urlAsset.url, creationDate: asset.creationDate)
                    
                    var processedIDs = Set<String>() // Track processed videos to prevent duplicates

                    let cacheKey = asset.localIdentifier
                    dispatchGroup.enter()

                    if let cachedImage = ThumbnailCache.shared.image(forKey: cacheKey) {
                        if !processedIDs.contains(video.id) {
                            processedIDs.insert(video.id)
                            video.thumbnail = cachedImage
                            self.videos.append(video)
                        }
                        dispatchGroup.leave()
                    } else {
                        let thumbnailSize = CGSize(width: 100, height: 100)
                        PHImageManager.default().requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: nil) { image, info in
                            if !processedIDs.contains(video.id) {
                                processedIDs.insert(video.id)
                                if let image = image {
                                    ThumbnailCache.shared.setImage(image, forKey: cacheKey)
                                    video.thumbnail = image
                                }
                                self.videos.append(video)
                            }
                            dispatchGroup.leave()
                        }
                    }
                } else {
                    dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            
        }
    }
}

struct VideoRow: View {
    let video: Video
    @State private var showError = false
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
                    if let date = video.creationDate {
                        Text("\(date, formatter: dateFormatter)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .alert(isPresented: $showError) {
                    Alert(title: Text("Could not cast video"), message: Text("Please connect to a chromecast device and try again."))
                }
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
        guard let currentCastSession = GCKCastContext.sharedInstance().sessionManager.currentCastSession else {
            GCKCastContext.sharedInstance().presentCastDialog()
            return
        }

        // Convert video if necessary
        LocalHTTPServer.shared.convertToMP4IfNeeded(url: video.url) { mp4URL in
            guard let mp4URL = mp4URL else {
                print("Failed to convert video to MP4")
                showError = true
                return
            }

            // Start the local server
            LocalHTTPServer.shared.startServer(withFileAt: mp4URL) { localURL in
                guard let localURL = localURL else {
                    print("Failed to create local URL")
                    showError = true
                    return
                }

                Task {
                    // Fetch video duration
                    let asset = AVAsset(url: mp4URL)
                    let duration = try await asset.load(.duration)

                    // Create Media Metadata
                    let metadata = GCKMediaMetadata()
                    metadata.setString(video.url.lastPathComponent, forKey: kGCKMetadataKeyTitle)
                    
                    // Use GCKMediaInformationBuilder
                    let mediaInfoBuilder = GCKMediaInformationBuilder(contentURL: localURL)
                    mediaInfoBuilder.streamType = GCKMediaStreamType.buffered
                    mediaInfoBuilder.contentType = "video/mp4"
                    mediaInfoBuilder.metadata = metadata
                    mediaInfoBuilder.streamDuration = duration.seconds
                    let mediaInfo = mediaInfoBuilder.build()
                    
                    // Cast the video to Chromecast
                    currentCastSession.remoteMediaClient?.loadMedia(mediaInfo)
                    GCKCastContext.sharedInstance().presentDefaultExpandedMediaControls()
                    GCKCastContext.sharedInstance().useDefaultExpandedMediaControls = true
                }
            }
        }
    }
}

struct CastButtonView: UIViewRepresentable {
    func makeUIView(context: Context) -> GCKUICastButton {
        let castButton = GCKUICastButton(frame: .zero)
        return castButton
    }

    func updateUIView(_ uiView: GCKUICastButton, context: Context) {
        
    }
}

class LocalHTTPServer {
    static let shared = LocalHTTPServer()
    private var webServer: GCDWebServer?
    private var _url: URL?
    var isRunningListener: Binding<Bool>?
    
    func startServer(completion: @escaping (URL?) -> Void) {
        if let url = _url {
            startServer(withFileAt: url) { url in completion(url) }
        }
    }
    
    func startServer(withFileAt url: URL, completion: @escaping (URL?) -> Void) {
        // Convert to MP4 if necessary
        convertToMP4IfNeeded(url: url) { mp4URL in
            guard let mp4URL = mp4URL else {
                print("Failed to convert video to MP4")
                completion(nil)
                return
            }

            // Stop any existing server
            if self.isServerRunning() {
                self.webServer?.stop()
            }

            self.webServer = GCDWebServer()
            self._url = mp4URL

            // Add a handler for the MP4 file
            self.webServer?.addHandler(forMethod: "GET", path: "/video.mp4", request: GCDWebServerRequest.self) { request in
                guard let mp4URL = self._url else {
                    return GCDWebServerErrorResponse(statusCode: 404)
                }

                let response = GCDWebServerFileResponse(file: mp4URL.path, isAttachment: false)
                response?.setValue("bytes", forAdditionalHeader: "Accept-Ranges")
                
                // Add logging for range requests
                if let rangeHeader = request.headers["Range"] {
                    print("Range request: \(rangeHeader)")
                }

                return response
            }

            self.isRunningListener?.wrappedValue = true

            // Start the server
            do {
                try self.webServer?.start(options: [
                    GCDWebServerOption_Port: 8080,
                    GCDWebServerOption_BindToLocalhost: false,
                    GCDWebServerOption_AutomaticallySuspendInBackground: false
                ])
                if let serverURL = self.webServer?.serverURL {
                    completion(serverURL.appendingPathComponent("video.mp4"))
                } else {
                    completion(nil)
                }
            } catch {
                print("Failed to start server: \(error.localizedDescription)")
                self.isRunningListener?.wrappedValue = false
                completion(nil)
            }
        }
    }

    func stopServer() {
        webServer?.stop()
        isRunningListener?.wrappedValue = false
    }
    
    func isServerRunning() -> Bool {
        webServer?.isRunning ?? false
    }
    
    func convertToMP4IfNeeded(url: URL, completion: @escaping (URL?) -> Void) {
        // Check if the file is already in MP4 format
        if url.pathExtension.lowercased() == "mp4" {
            completion(url) // No conversion needed
            return
        }

        // Define a temporary output path for the converted file
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        // FFmpeg command to convert the video to MP4 with H.264 codec
        let ffmpegCommand = """
        -i "\(url.path)" -c:v h264_videotoolbox -crf 30 -preset ultrafast -c:a aac -strict experimental "\(tempURL.path)"
        """
        // Execute FFmpegKit command
        FFmpegKit.executeAsync(ffmpegCommand) { session in
            let returnCode = session?.getReturnCode()

            if ReturnCode.isSuccess(returnCode) {
                DispatchQueue.main.async {
                    print("Conversion to MP4 with H.264 completed: \(tempURL)")
                    completion(tempURL) // Return the converted file
                }
            } else {
                DispatchQueue.main.async {
                    print("Failed to convert video with FFmpeg: \(returnCode?.getValue() ?? -1)")
                    completion(nil) // Notify failure
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
