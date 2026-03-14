// Move.swift
// Defines positions, move types, and moves in algebraic notation

import Foundation

/// A position on the chess board (rank 0-7, file 0-7)
/// rank 0 = rank 1 (white's back rank), rank 7 = rank 8 (black's back rank)
/// file 0 = file a, file 7 = file h
struct Position: Equatable, Hashable, Codable {
    let rank: Int  // 0-7
    let file: Int  // 0-7

    init(_ rank: Int, _ file: Int) {
        self.rank = rank
        self.file = file
    }

    /// Returns true if the position is within board bounds
    var isValid: Bool {
        return rank >= 0 && rank < 8 && file >= 0 && file < 8
    }

    /// Algebraic notation for this square (e.g., "e4")
    var algebraic: String {
        let fileChar = String(UnicodeScalar(UInt8(file) + 97)) // a=97
        return "\(fileChar)\(rank + 1)"
    }

    /// Create from algebraic notation
    static func from(algebraic: String) -> Position? {
        guard algebraic.count == 2 else { return nil }
        let chars = Array(algebraic)
        guard let fileVal = chars[0].asciiValue.map({ Int($0) - 97 }),
              let rankVal = chars[1].wholeNumberValue else { return nil }
        let pos = Position(rankVal - 1, fileVal)
        return pos.isValid ? pos : nil
    }
}

/// The type of move being made
enum MoveType: Equatable, Codable {
    case normal
    case capture
    case enPassant
    case castleKingside
    case castleQueenside
    case promotion(PieceType)
    case promotionCapture(PieceType)
}

/// A chess move from one square to another
struct Move: Equatable, Codable {
    let from: Position
    let to: Position
    let piece: Piece
    let captured: Piece?
    let moveType: MoveType

    init(from: Position, to: Position, piece: Piece, captured: Piece? = nil, moveType: MoveType = .normal) {
        self.from = from
        self.to = to
        self.piece = piece
        self.captured = captured
        self.moveType = moveType
    }

    /// Standard algebraic notation (SAN) for this move
    /// Note: full disambiguation requires board context; this is a simplified version
    var algebraicNotation: String {
        switch moveType {
        case .castleKingside:
            return "O-O"
        case .castleQueenside:
            return "O-O-O"
        case .promotion(let promoPiece), .promotionCapture(let promoPiece):
            let captureStr = (captured != nil) ? "\(fromFileChar)x" : ""
            return "\(captureStr)\(to.algebraic)=\(pieceChar(promoPiece))"
        default:
            let piecePrefix = piece.type == .pawn ? "" : pieceChar(piece.type)
            let captureStr = captured != nil ? (piece.type == .pawn ? "\(fromFileChar)x" : "x") : ""
            return "\(piecePrefix)\(captureStr)\(to.algebraic)"
        }
    }

    private var fromFileChar: String {
        return String(UnicodeScalar(UInt8(from.file) + 97))
    }

    private func pieceChar(_ type: PieceType) -> String {
        switch type {
        case .king:   return "K"
        case .queen:  return "Q"
        case .rook:   return "R"
        case .bishop: return "B"
        case .knight: return "N"
        case .pawn:   return ""
        }
    }

    /// Whether this move is a capture of any kind
    var isCapture: Bool {
        switch moveType {
        case .capture, .enPassant, .promotionCapture: return true
        default: return false
        }
    }
}
