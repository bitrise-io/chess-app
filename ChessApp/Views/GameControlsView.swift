// GameControlsView.swift
// Game control buttons and settings

import SwiftUI

struct GameControlsView: View {
    @ObservedObject var viewModel: GameViewModel
    @State private var showNewGameConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status
            statusView

            Divider()

            // Mode Selection
            modeSelectionView

            Divider()

            // Action Buttons
            actionButtonsView
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .alert("New Game", isPresented: $showNewGameConfirm) {
            Button("New Game", role: .destructive) { viewModel.newGame() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Start a new game? Current game will be lost.")
        }
    }

    @ViewBuilder
    private var statusView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Status")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                if viewModel.isAIThinking {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("AI thinking...")
                        .font(.body)
                        .foregroundColor(.secondary)
                } else {
                    Text(viewModel.statusMessage)
                        .font(.body.bold())
                        .foregroundColor(statusColor)
                }
            }
        }
    }

    private var statusColor: Color {
        switch viewModel.gameState.result {
        case .ongoing: return .primary
        case .checkmate: return .red
        case .draw: return .orange
        }
    }

    @ViewBuilder
    private var modeSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Game Mode")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Mode", selection: gameModeBinding) {
                Text("Player vs Player").tag(0)
                Text("vs AI (White)").tag(1)
                Text("vs AI (Black)").tag(2)
            }
            .pickerStyle(.menu)

            if case .vsAI(_, _) = viewModel.gameMode {
                Text("Difficulty")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Difficulty", selection: difficultyBinding) {
                    ForEach(Difficulty.allCases, id: \.self) { diff in
                        Text(diff.rawValue).tag(diff)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    @ViewBuilder
    private var actionButtonsView: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    if viewModel.gameState.moveHistory.isEmpty {
                        viewModel.newGame()
                    } else {
                        showNewGameConfirm = true
                    }
                } label: {
                    Label("New Game", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut("n", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button {
                    viewModel.flipBoard()
                } label: {
                    Label("Flip", systemImage: "arrow.up.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Button {
                    viewModel.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut("z", modifiers: .command)
                .buttonStyle(.bordered)
                .disabled(viewModel.gameState.moveHistory.isEmpty || viewModel.isAIThinking)

                Button {
                    viewModel.resign()
                } label: {
                    Label("Resign", systemImage: "flag")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(viewModel.gameState.result != .ongoing || viewModel.isAIThinking)
            }
        }
    }

    // MARK: - Bindings

    private var gameModeBinding: Binding<Int> {
        Binding {
            switch viewModel.gameMode {
            case .pvp: return 0
            case .vsAI(let color, _): return color == .white ? 2 : 1
            }
        } set: { newVal in
            switch newVal {
            case 0: viewModel.gameMode = .pvp
            case 1: viewModel.gameMode = .vsAI(color: .black, difficulty: currentDifficulty)
            case 2: viewModel.gameMode = .vsAI(color: .white, difficulty: currentDifficulty)
            default: break
            }
        }
    }

    private var difficultyBinding: Binding<Difficulty> {
        Binding {
            currentDifficulty
        } set: { newDiff in
            if case .vsAI(let color, _) = viewModel.gameMode {
                viewModel.gameMode = .vsAI(color: color, difficulty: newDiff)
            }
        }
    }

    private var currentDifficulty: Difficulty {
        if case .vsAI(_, let diff) = viewModel.gameMode { return diff }
        return .intermediate
    }
}
