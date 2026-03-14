// GameViewModel.swift
// MVVM ViewModel managing game state, user interactions, and AI

import Foundation
import Combine

/// Game mode: player vs player or player vs AI
enum GameMode: Equatable {
    case pvp
    case vsAI(color: PieceColor, difficulty: Difficulty)
}

/// The view model bridging game state to views
class GameViewModel: ObservableObject {
    @Published var gameState: GameState
    @Published var selectedSquare: Position?
    @Published var legalMovesForSelected: [Move] = []
    @Published var isFlipped: Bool = false
    @Published var gameMode: GameMode = .vsAI(color: .black, difficulty: .intermediate)
    @Published var isAIThinking: Bool = false
    @Published var promotionPending: (from: Position, to: Position, piece: Piece)?
    @Published var statusMessage: String = "White to move"

    private let engine = ChessEngine()
    private var aiTask: Task<Void, Never>? = nil

    init() {
        gameState = GameState()
    }

    // MARK: - Square Selection & Move Execution

    /// Handle a tap/click on a board square
    func selectSquare(at position: Position) {
        guard gameState.result == .ongoing else { return }

        // Don't allow moves when it's AI's turn
        if case .vsAI(let aiColor, _) = gameMode, gameState.activeColor == aiColor { return }

        if let selected = selectedSquare {
            // Try to make a move to the tapped square
            if let move = legalMovesForSelected.first(where: { $0.to == position }) {
                // Check if this is a promotion
                if case .promotion(_) = move.moveType {
                    // Show promotion picker - collect all promotion moves to this square
                    promotionPending = (from: selected, to: position, piece: move.piece)
                    return
                }
                if case .promotionCapture(_) = move.moveType {
                    promotionPending = (from: selected, to: position, piece: move.piece)
                    return
                }
                executeMove(move)
                selectedSquare = nil
                legalMovesForSelected = []
            } else if let piece = gameState.board[position], piece.color == gameState.activeColor {
                // Select a different piece of the same color
                selectedSquare = position
                legalMovesForSelected = engine.generateLegalMoves(for: gameState.activeColor, in: gameState)
                    .filter { $0.from == position }
            } else {
                // Deselect
                selectedSquare = nil
                legalMovesForSelected = []
            }
        } else {
            // Select a piece
            if let piece = gameState.board[position], piece.color == gameState.activeColor {
                selectedSquare = position
                legalMovesForSelected = engine.generateLegalMoves(for: gameState.activeColor, in: gameState)
                    .filter { $0.from == position }
            }
        }
    }

    /// Handle a drag from one position to another
    func dragPiece(from: Position, to: Position) {
        guard gameState.result == .ongoing else { return }
        if case .vsAI(let aiColor, _) = gameMode, gameState.activeColor == aiColor { return }
        guard let piece = gameState.board[from], piece.color == gameState.activeColor else { return }

        let moves = engine.generateLegalMoves(for: gameState.activeColor, in: gameState)
            .filter { $0.from == from && $0.to == to }

        guard !moves.isEmpty else {
            selectedSquare = nil
            legalMovesForSelected = []
            return
        }

        let move = moves[0]
        if case .promotion(_) = move.moveType {
            promotionPending = (from: from, to: to, piece: piece)
            return
        }
        if case .promotionCapture(_) = move.moveType {
            promotionPending = (from: from, to: to, piece: piece)
            return
        }

        executeMove(move)
        selectedSquare = nil
        legalMovesForSelected = []
    }

    /// Complete a pending promotion with the chosen piece type
    func completePromotion(with pieceType: PieceType) {
        guard let pending = promotionPending else { return }

        // Find the matching promotion move
        let allMoves = engine.generateLegalMoves(for: gameState.activeColor, in: gameState)
        let move = allMoves.first { m in
            m.from == pending.from && m.to == pending.to &&
            (m.moveType == .promotion(pieceType) || m.moveType == .promotionCapture(pieceType))
        }

        promotionPending = nil
        selectedSquare = nil
        legalMovesForSelected = []

        if let move = move {
            executeMove(move)
        }
    }

    /// Execute a validated move
    private func executeMove(_ move: Move) {
        // Play sound
        let event: SoundEvent
        if engine.isInCheck(color: gameState.activeColor.opponent, board: gameState.board.applying(move)) {
            event = .check
        } else if case .castleKingside = move.moveType { event = .castle }
        else if case .castleQueenside = move.moveType { event = .castle }
        else if move.isCapture { event = .capture }
        else { event = .move }

        gameState.apply(move)
        SoundManager.shared.play(event)

        // Check game result
        updateGameResult()

        // Trigger AI move if needed
        if gameState.result == .ongoing {
            triggerAIMoveIfNeeded()
        }
    }

    private func updateGameResult() {
        let color = gameState.activeColor

        if engine.isCheckmate(color: color, in: gameState) {
            gameState.result = .checkmate(winner: color.opponent)
            SoundManager.shared.play(.gameEnd)
            statusMessage = gameState.result.description
        } else if engine.isStalemate(color: color, in: gameState) {
            gameState.result = .draw(reason: .stalemate)
            SoundManager.shared.play(.gameEnd)
            statusMessage = gameState.result.description
        } else if gameState.isFiftyMoveRule {
            gameState.result = .draw(reason: .fiftyMoveRule)
            statusMessage = gameState.result.description
        } else if gameState.isThreefoldRepetition {
            gameState.result = .draw(reason: .threefoldRepetition)
            statusMessage = gameState.result.description
        } else if engine.hasInsufficientMaterial(in: gameState) {
            gameState.result = .draw(reason: .insufficientMaterial)
            statusMessage = gameState.result.description
        } else {
            let inCheck = engine.isInCheck(color: color, board: gameState.board)
            statusMessage = "\(color.name) to move\(inCheck ? " (Check!)" : "")"
        }
    }

    // MARK: - AI

    private func triggerAIMoveIfNeeded() {
        guard case .vsAI(let aiColor, let difficulty) = gameMode,
              gameState.activeColor == aiColor,
              gameState.result == .ongoing else { return }

        isAIThinking = true
        let stateCopy = gameState

        aiTask?.cancel()
        aiTask = Task {
            // Add slight delay so UI updates first
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s

            let move = engine.bestMove(for: aiColor, in: stateCopy, difficulty: difficulty)

            await MainActor.run {
                self.isAIThinking = false
                if let move = move, !Task.isCancelled {
                    self.executeMove(move)
                }
            }
        }
    }

    // MARK: - Game Controls

    func newGame() {
        aiTask?.cancel()
        gameState = GameState()
        selectedSquare = nil
        legalMovesForSelected = []
        promotionPending = nil
        isAIThinking = false
        statusMessage = "White to move"

        // If AI plays white, trigger immediately
        triggerAIMoveIfNeeded()
    }

    func undo() {
        guard !gameState.moveHistory.isEmpty else { return }
        aiTask?.cancel()
        isAIThinking = false

        // In vs AI mode, undo two moves (player's and AI's)
        var movesToUndo = 1
        if case .vsAI(_, _) = gameMode, gameState.moveHistory.count >= 2 {
            movesToUndo = 2
        }

        // Rebuild state from scratch up to moveHistory.count - movesToUndo
        let targetCount = max(0, gameState.moveHistory.count - movesToUndo)
        let movesToReplay = Array(gameState.moveHistory.prefix(targetCount))

        gameState = GameState()
        for move in movesToReplay {
            // Re-find the move from engine to apply correctly
            gameState.apply(move)
        }

        selectedSquare = nil
        legalMovesForSelected = []
        promotionPending = nil
        updateStatusAfterUndo()
    }

    private func updateStatusAfterUndo() {
        let color = gameState.activeColor
        let inCheck = engine.isInCheck(color: color, board: gameState.board)
        statusMessage = "\(color.name) to move\(inCheck ? " (Check!)" : "")"
    }

    func resign() {
        guard gameState.result == .ongoing else { return }
        aiTask?.cancel()
        gameState.result = .checkmate(winner: gameState.activeColor.opponent)
        statusMessage = "\(gameState.activeColor.name) resigned. \(gameState.activeColor.opponent.name) wins!"
        SoundManager.shared.play(.gameEnd)
    }

    func flipBoard() {
        isFlipped.toggle()
    }

    // MARK: - Helpers

    /// Returns the last move made (for highlighting)
    var lastMove: Move? {
        return gameState.moveHistory.last
    }

    /// Returns display ranks/files in correct order for current orientation
    var displayRanks: [Int] {
        isFlipped ? Array(0..<8) : Array((0..<8).reversed())
    }

    var displayFiles: [Int] {
        isFlipped ? Array((0..<8).reversed()) : Array(0..<8)
    }
}
