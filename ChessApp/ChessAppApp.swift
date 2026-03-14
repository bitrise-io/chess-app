// ChessAppApp.swift
// The main entry point for the Chess application

import SwiftUI

@main
struct ChessAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // Override default menu items with chess-specific ones
            CommandGroup(replacing: .newItem) {
                // New Game is handled via keyboard shortcut in GameControlsView
            }
        }
        .defaultSize(width: 900, height: 700)
    }
}
