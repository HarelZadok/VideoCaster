//
//  LocalHTTPServer.swift
//  VideoCaster
//
//  Created by Harel Zadok on 11/01/2025.
//

import SwiftUI
import GCDWebServer
import ffmpegkit

class LocalHTTPServer {
    static let shared = LocalHTTPServer()
    private var webServer: GCDWebServer = GCDWebServer()
    private var _url: URL?
    private var _thumbnail: UIImage?
    var convertingFile = false
    private var onServerStateChangeHandlers: [(Bool) -> Void] = []
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    public func onServerStateChange(_ handler: @escaping (Bool) -> Void) {
        onServerStateChangeHandlers.append(handler)
    }
    
    func startServer(completion: @escaping (URL?) -> Void) {
        if let url = _url {
            startServer(withFileAt: url) { url in completion(url) }
        }
    }
    
    func startServer(withFileAt url: URL, thumbnail: UIImage? = nil, completion: @escaping (URL?) -> Void) {
        // Stop any existing server
        if self.isServerRunning() {
            self.stopServer()
        }
        
        self._url = url
        self._thumbnail = thumbnail
        
        self.webServer.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self) { request in
            return GCDWebServerDataResponse(html: "<html><body><h1>Hello from GCDWebServer!</h1></body></html>")
        }
        
        // Add a handler for the MP4 file
        self.webServer.addHandler(forMethod: "GET", path: "/video.mp4", request: GCDWebServerRequest.self) { request in
            guard let url = self._url else {
                return GCDWebServerErrorResponse(statusCode: 404)
            }
            
            let response = GCDWebServerFileResponse(file: url.path, byteRange: request.byteRange, isAttachment: false)
            response?.setValue("bytes", forAdditionalHeader: "Accept-Ranges")
            response?.contentType = "video/mp4"
            response?.setValue("keep-alive", forAdditionalHeader: "Connection")
            response?.setValue("inline; filename=\"video.mp4\"", forAdditionalHeader: "Content-Disposition")
            return response
        }
        
        self.webServer.addHandler(forMethod: "GET", path: "/thumbnail.jpg", request: GCDWebServerRequest.self) { request  in
            guard let jpg = self._thumbnail else {
                return GCDWebServerErrorResponse(statusCode: 404)
            }

            return GCDWebServerDataResponse(data: jpg.jpegData(compressionQuality: 1)!, contentType: "image/jpeg")
        }

        // Start the server
        do {
            try self.webServer.start(options: [
                GCDWebServerOption_Port: 0,
                GCDWebServerOption_BindToLocalhost: false,
                GCDWebServerOption_AutomaticallySuspendInBackground: false,
            ])
            if let serverURL = self.webServer.serverURL {
                self.notifyServerStateChange(true)
                
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
                    if success {
                        print("All set!")
                    } else if let error {
                        print(error.localizedDescription)
                    }
                }
                
                let content = UNMutableNotificationContent()
                content.title = "ServerURL"
                content.subtitle = serverURL.absoluteString
                content.sound = UNNotificationSound.default

                // show this notification five seconds from now
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

                // choose a random identifier
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

                // add our notification request
                UNUserNotificationCenter.current().add(request)
                completion(serverURL)
            } else {
                completion(nil)
            }
        } catch {
            print("Failed to start server: \(error.localizedDescription)")
            self.notifyServerStateChange(false)
            completion(nil)
        }
    }
    
    private func notifyServerStateChange(_ state: Bool) {
        onServerStateChangeHandlers.forEach { $0(state) }
    }

    func stopServer() {
        webServer.stop()
        self.notifyServerStateChange(false)
    }
    
    func isServerRunning() -> Bool {
        webServer.isRunning
    }
    
    func isConvertingFile() -> Bool {
        return convertingFile
    }
    
    func convertToMP4IfNeeded(url: URL, completion: @escaping (URL?) -> Void) {
        // Check if the file is already in MP4 format
        if url.pathExtension.lowercased() != "mkv" {
            completion(url) // No conversion needed
            return
        }

        convertingFile = true
        
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
                    completion(tempURL) // Return the converted file
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil) // Notify failure
                }
            }
        }
        convertingFile = false
    }
}
