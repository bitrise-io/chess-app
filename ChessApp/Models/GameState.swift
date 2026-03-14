// GameState.swift
// Tracks all state needed for a chess game in progress

import Foundation

/// Reason for a draw
enum DrawReason: String, Codable {
    case fiftyMoveRule = "50-Move Rule"
    case threefoldRepetition = "Threefold Repetition"
    case insufficientMaterial = "Insufficient Material"
    case stalemate = "Stalemate"
}

/// The result of a game
enum GameResult: Equatable, Codable {
    case ongoing
    case checkmate(winner: PieceColor)
    case draw(reason: DrawReason)

    var isOver: Bool {
        return self != .ongoing
    }

    var description: String {
        switch self {
        case .ongoing: return "Game in progress"
        case .checkmate(let winner): return "\(winner.name) wins by checkmate!"
        case .draw(let reason): return "Draw by \(reason.rawValue)"
        }
    }
}

/// Castling rights for both colors
struct CastlingRights: Equatable, Codable {
    var whiteKingside:  Bool = true
    var whiteQueenside: Bool = true
    var blackKingside:  Bool = true
    var blackQueenside: Bool = true

    func kingside(for color: PieceColor) -> Bool {
        return color == .white ? whiteKingside : blackKingside
    }

    func queenside(for color: PieceColor) -> Bool {
        return color == .white ? whiteQueenside : blackQueenside
    }

    mutating func revokeAll(for color: PieceColor) {
        if color == .white {
            whiteKingside = false
            whiteQueenside = false
        } else {
            blackKingside = false
            blackQueenside = false
        }
    }

    /// FEN castling rights string
    var fenString: String {
        var s = ""
        if whiteKingside  { s += "K" }
        if whiteQueenside { s += "Q" }
        if blackKingside  { s += "k" }
        if blackQueenside { s += "q" }
        return s.isEmpty ? "-" : s
    }
}

/// A snapshot of the full game state (for threefold repetition)
struct StateSnapshot: Equatable, Codable {
    let piecePlacement: String
    let activeColor: PieceColor
    let castlingRights: CastlingRights
    let enPassantTarget: String  // "-" or algebraic square
}

/// The complete state of a chess game
struct GameState: Codable {
    var board: Board
    var activeColor: PieceColor
    var castlingRights: CastlingRights
    var enPassantTarget: Position?   // The square a pawn can move to for en passant
    var halfMoveClock: Int           // For 50-move rule
    var fullMoveNumber: Int
    var moveHistory: [Move]
    var positionHistory: [StateSnapshot]  // For threefold repetition
    var result: GameResult

    // MARK: - Initialization

    init() {
        board = Board.initialBoard()
        activeColor = .white
        castlingRights = CastlingRights()
        enPassantTarget = nil
        halfMoveClock = 0
        fullMoveNumber = 1
        moveHistory = []
        positionHistory = []
        result = .ongoing
    }

    // MARK: - State Snapshot

    var snapshot: StateSnapshot {
        StateSnapshot(
            piecePlacement: board.fenPiecePlacement,
            activeColor: activeColor,
            castlingRights: castlingRights,
            enPassantTarget: enPassantTarget?.algebraic ?? "-"
        )
    }

    // MARK: - Move Application

    /// Applies a move and updates all game state accordingly
    mutating func apply(_ move: Move) {
        board = board.applying(move)

        // Update en passant target
        if move.piece.type == .pawn && abs(move.to.rank - move.from.rank) == 2 {
            // Double pawn push: set en passant target
            let epRank = (move.from.rank + move.to.rank) / 2
            enPassantTarget = Position(epRank, move.from.file)
        } else {
            enPassantTarget = nil
        }

        // Update castling rights when king or rook moves
        updateCastlingRights(after: move)

        // Update half-move clock
        if move.piece.type == .pawn || move.isCapture {
            halfMoveClock = 0
        } else {
            halfMoveClock += 1
        }

        // Update full move number
        if activeColor == .black {
            fullMoveNumber += 1
        }

        // Record move
        moveHistory.append(move)

        // Switch active color
        activeColor = activeColor.opponent

        // Record position for threefold repetition
        positionHistory.append(snapshot)
    }

    private mutating func updateCastlingRights(after move: Move) {
        // King moved: revoke both castling rights
        if move.piece.type == .king {
            castlingRights.revokeAll(for: move.piece.color)
        }

        // Rook moved or captured: revoke specific side
        // White rooks
        if move.from == Position(0, 0) { castlingRights.whiteQueenside = false }
        if move.from == Position(0, 7) { castlingRights.whiteKingside = false }
        // Black rooks
        if move.from == Position(7, 0) { castlingRights.blackQueenside = false }
        if move.from == Position(7, 7) { castlingRights.blackKingside = false }

        // Rook captured at original square
        if move.to == Position(0, 0) { castlingRights.whiteQueenside = false }
        if move.to == Position(0, 7) { castlingRights.whiteKingside = false }
        if move.to == Position(7, 0) { castlingRights.blackQueenside = false }
        if move.to == Position(7, 7) { castlingRights.blackKingside = false }
    }

    // MARK: - Draw Conditions

    var isThreefoldRepetition: Bool {
        let current = snapshot
        let count = positionHistory.filter { $0 == current }.count
        return count >= 3
    }

    var isFiftyMoveRule: Bool {
        return halfMoveClock >= 100  // 50 moves = 100 half-moves
    }

    var isFEN: String {
        let ep = enPassantTarget?.algebraic ?? "-"
        return "\(board.fenPiecePlacement) \(activeColor == .white ? "w" : "b") \(castlingRights.fenString) \(ep) \(halfMoveClock) \(fullMoveNumber)"
    }
}
