//
//  AudioSessionManager.swift
//  VideoCaster
//
//  Created by Harel Zadok on 28/01/2025.
//


//
//  AudioSessionManager.swift
//  VideoCaster
//
//  Created by Harel Zadok on 28/01/2025.
//

import AVFoundation
import MediaPlayer

class AudioSessionManager {
    static let shared = AudioSessionManager()
    private var silentPlayer: AVAudioPlayer?
    
    private init() {}
    
    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
            print("Audio session configured.")
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    func startSilentAudio() {
        guard let url = Bundle.main.url(forResource: "silent", withExtension: "mp3") else {
            print("Silent audio file not found.")
            return
        }
        do {
            silentPlayer = try AVAudioPlayer(contentsOf: url)
            silentPlayer?.numberOfLoops = -1 // Loop indefinitely
            silentPlayer?.volume = 0.0       // Mute the audio
            silentPlayer?.play()
            print("Silent audio started.")
        } catch {
            print("Failed to play silent audio: \(error)")
        }
    }
    
    func stopSilentAudio() {
        silentPlayer?.stop()
        silentPlayer = nil
        print("Silent audio stopped.")
    }
}
