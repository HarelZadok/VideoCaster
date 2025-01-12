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
    var convertingFile = false
    private var onServerStateChangeHandlers: [(Bool) -> Void] = []
    
    public func onServerStateChange(_ handler: @escaping (Bool) -> Void) {
        onServerStateChangeHandlers.append(handler)
    }
    
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
                self.stopServer()
            }
            
            self._url = mp4URL
            
            // Add a handler for the MP4 file
            self.webServer.addHandler(forMethod: "GET", path: "/video.mp4", request: GCDWebServerRequest.self) { request in
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

            // Start the server
            do {
                try self.webServer.start(options: [
                    GCDWebServerOption_Port: 0,
                    GCDWebServerOption_BindToLocalhost: false,
                    GCDWebServerOption_AutomaticallySuspendInBackground: false,
                ])
                if let serverURL = self.webServer.serverURL {
                    self.notifyServerStateChange(true)
                    completion(serverURL.appendingPathComponent("video.mp4"))
                } else {
                    completion(nil)
                }
            } catch {
                print("Failed to start server: \(error.localizedDescription)")
                self.notifyServerStateChange(false)
                completion(nil)
            }
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
        if url.pathExtension.lowercased() == "mp4" {
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
        convertingFile = false
    }
}
