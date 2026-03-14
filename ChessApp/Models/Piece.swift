// Piece.swift
// Defines the fundamental chess piece types, colors, and piece representation

import Foundation

/// The type of chess piece
enum PieceType: Int, CaseIterable, Codable {
    case king = 0
    case queen
    case rook
    case bishop
    case knight
    case pawn

    /// Material value in centipawns
    var value: Int {
        switch self {
        case .king:   return 20000
        case .queen:  return 900
        case .rook:   return 500
        case .bishop: return 330
        case .knight: return 320
        case .pawn:   return 100
        }
    }

    var name: String {
        switch self {
        case .king:   return "King"
        case .queen:  return "Queen"
        case .rook:   return "Rook"
        case .bishop: return "Bishop"
        case .knight: return "Knight"
        case .pawn:   return "Pawn"
        }
    }
}

/// The color of a chess piece or square
enum PieceColor: Int, CaseIterable, Codable {
    case white = 0
    case black = 1

    /// Returns the opposing color
    var opponent: PieceColor {
        return self == .white ? .black : .white
    }

    var name: String {
        return self == .white ? "White" : "Black"
    }
}

/// A chess piece with a type and color
struct Piece: Equatable, Codable, Hashable {
    let type: PieceType
    let color: PieceColor

    init(_ type: PieceType, _ color: PieceColor) {
        self.type = type
        self.color = color
    }

    /// Unicode chess symbol for display
    var symbol: String {
        switch (type, color) {
        case (.king,   .white): return "♔"
        case (.queen,  .white): return "♕"
        case (.rook,   .white): return "♖"
        case (.bishop, .white): return "♗"
        case (.knight, .white): return "♘"
        case (.pawn,   .white): return "♙"
        case (.king,   .black): return "♚"
        case (.queen,  .black): return "♛"
        case (.rook,   .black): return "♜"
        case (.bishop, .black): return "♝"
        case (.knight, .black): return "♞"
        case (.pawn,   .black): return "♟"
        }
    }

    /// FEN character representation
    var fenChar: Character {
        let chars: [PieceType: Character] = [
            .king: "k", .queen: "q", .rook: "r",
            .bishop: "b", .knight: "n", .pawn: "p"
        ]
        let c = chars[type]!
        return color == .white ? Character(c.uppercased()) : c
    }
}
