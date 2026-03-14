// ContentView.swift
// Main layout: board on left, sidebar (history + controls) on right

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()

    var body: some View {
        HSplitView {
            // Left: Chess board
            boardPanel

            // Right: Sidebar
            sidebarPanel
        }
        .frame(minWidth: 700, minHeight: 500)
        // Promotion overlay
        .overlay {
            if let pending = viewModel.promotionPending {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {} // Block taps

                PromotionPickerView(color: pending.piece.color) { pieceType in
                    viewModel.completePromotion(with: pieceType)
                }
            }
        }
        // Game over overlay
        .overlay(alignment: .top) {
            if viewModel.gameState.result != .ongoing {
                gameOverBanner
            }
        }
    }

    @ViewBuilder
    private var boardPanel: some View {
        VStack(spacing: 0) {
            // Active player indicator
            playerIndicator(color: viewModel.isFlipped ? .white : .black, isTop: true)

            BoardView(viewModel: viewModel)
                .padding(12)

            playerIndicator(color: viewModel.isFlipped ? .black : .white, isTop: false)
        }
        .frame(minWidth: 400, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func playerIndicator(color: PieceColor, isTop: Bool) -> some View {
        HStack {
            Image(systemName: color == .white ? "circle.fill" : "circle.inset.filled")
                .foregroundColor(color == .white ? .white : .black)
                .shadow(radius: 1)
            Text(color.name)
                .font(.subheadline.bold())
            if viewModel.gameState.activeColor == color && viewModel.gameState.result == .ongoing {
                Image(systemName: "clock")
                    .foregroundColor(.accentColor)
                    .font(.caption)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(
            viewModel.gameState.activeColor == color && viewModel.gameState.result == .ongoing
                ? Color.accentColor.opacity(0.1)
                : Color.clear
        )
    }

    @ViewBuilder
    private var sidebarPanel: some View {
        VStack(spacing: 0) {
            MoveHistoryView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            GameControlsView(viewModel: viewModel)
        }
        .frame(minWidth: 220, maxWidth: 280)
    }

    @ViewBuilder
    private var gameOverBanner: some View {
        HStack {
            Image(systemName: resultIcon)
                .font(.title2)
            Text(viewModel.gameState.result.description)
                .font(.headline)
            Spacer()
            Button("New Game") { viewModel.newGame() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(bannerColor)
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
        .shadow(radius: 5)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(), value: viewModel.gameState.result != .ongoing)
    }

    private var resultIcon: String {
        switch viewModel.gameState.result {
        case .checkmate: return "crown.fill"
        case .draw: return "equal.circle.fill"
        case .ongoing: return "circle"
        }
    }

    private var bannerColor: Color {
        switch viewModel.gameState.result {
        case .checkmate(let winner):
            return winner == .white ? Color.white.opacity(0.9) : Color(white: 0.15).opacity(0.9)
        case .draw:
            return Color.orange.opacity(0.85)
        case .ongoing:
            return Color.clear
        }
    }
}

#Preview {
    ContentView()
}
