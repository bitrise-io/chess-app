// SoundManager.swift
// Manages sound effects for chess moves using NSSound on macOS

import Foundation
import AppKit

/// Sound events in the chess game
enum SoundEvent {
    case move
    case capture
    case check
    case castle
    case gameEnd
}

/// Manages playing sound effects
class SoundManager {
    static let shared = SoundManager()

    private var isMuted = false

    private init() {}

    func play(_ event: SoundEvent) {
        guard !isMuted else { return }

        // Use system sounds as fallback since we have no bundled audio files
        let soundName: String
        switch event {
        case .move:    soundName = "Tink"
        case .capture: soundName = "Funk"
        case .check:   soundName = "Basso"
        case .castle:  soundName = "Glass"
        case .gameEnd: soundName = "Hero"
        }

        // NSSound.Name is just a String typealias
        if let sound = NSSound(named: NSSound.Name(soundName)) {
            sound.play()
        }
    }

    func toggleMute() {
        isMuted.toggle()
    }
}
