// Board.swift
// Represents the 8x8 chess board and handles piece placement

import Foundation

/// The chess board: an 8x8 grid of optional Piece values
struct Board: Equatable, Codable {
    // Grid stored as flat array [rank * 8 + file]
    private var grid: [Piece?]

    init() {
        grid = Array(repeating: nil, count: 64)
    }

    // MARK: - Access

    subscript(rank: Int, file: Int) -> Piece? {
        get { grid[rank * 8 + file] }
        set { grid[rank * 8 + file] = newValue }
    }

    subscript(position: Position) -> Piece? {
        get { grid[position.rank * 8 + position.file] }
        set { grid[position.rank * 8 + position.file] = newValue }
    }

    // MARK: - Setup

    /// Sets the board to the standard chess starting position
    static func initialBoard() -> Board {
        var board = Board()

        // White pieces (rank 0 and 1)
        board[0, 0] = Piece(.rook,   .white)
        board[0, 1] = Piece(.knight, .white)
        board[0, 2] = Piece(.bishop, .white)
        board[0, 3] = Piece(.queen,  .white)
        board[0, 4] = Piece(.king,   .white)
        board[0, 5] = Piece(.bishop, .white)
        board[0, 6] = Piece(.knight, .white)
        board[0, 7] = Piece(.rook,   .white)
        for file in 0..<8 {
            board[1, file] = Piece(.pawn, .white)
        }

        // Black pieces (rank 7 and 6)
        board[7, 0] = Piece(.rook,   .black)
        board[7, 1] = Piece(.knight, .black)
        board[7, 2] = Piece(.bishop, .black)
        board[7, 3] = Piece(.queen,  .black)
        board[7, 4] = Piece(.king,   .black)
        board[7, 5] = Piece(.bishop, .black)
        board[7, 6] = Piece(.knight, .black)
        board[7, 7] = Piece(.rook,   .black)
        for file in 0..<8 {
            board[6, file] = Piece(.pawn, .black)
        }

        return board
    }

    // MARK: - Move Execution

    /// Applies a move to the board and returns the resulting board
    /// Does NOT update game state (castling rights, en passant, etc.)
    func applying(_ move: Move) -> Board {
        var newBoard = self
        newBoard[move.to] = move.piece
        newBoard[move.from] = nil

        switch move.moveType {
        case .enPassant:
            // Remove the captured pawn (which is on the same rank as 'from', same file as 'to')
            let capturedPawnRank = move.from.rank
            let capturedPawnFile = move.to.file
            newBoard[capturedPawnRank, capturedPawnFile] = nil

        case .castleKingside:
            // Move the rook
            let rank = move.from.rank
            newBoard[rank, 7] = nil
            newBoard[rank, 5] = Piece(.rook, move.piece.color)

        case .castleQueenside:
            let rank = move.from.rank
            newBoard[rank, 0] = nil
            newBoard[rank, 3] = Piece(.rook, move.piece.color)

        case .promotion(let promoPiece):
            newBoard[move.to] = Piece(promoPiece, move.piece.color)

        case .promotionCapture(let promoPiece):
            newBoard[move.to] = Piece(promoPiece, move.piece.color)

        default:
            break
        }

        return newBoard
    }

    // MARK: - FEN Support

    /// Returns a FEN-like piece placement string
    var fenPiecePlacement: String {
        var result = ""
        for rank in stride(from: 7, through: 0, by: -1) {
            var emptyCount = 0
            for file in 0..<8 {
                if let piece = self[rank, file] {
                    if emptyCount > 0 {
                        result += "\(emptyCount)"
                        emptyCount = 0
                    }
                    result += String(piece.fenChar)
                } else {
                    emptyCount += 1
                }
            }
            if emptyCount > 0 { result += "\(emptyCount)" }
            if rank > 0 { result += "/" }
        }
        return result
    }

    // MARK: - Piece Finding

    /// Finds the position of the king of the given color
    func kingPosition(for color: PieceColor) -> Position? {
        for rank in 0..<8 {
            for file in 0..<8 {
                if let piece = self[rank, file], piece.type == .king, piece.color == color {
                    return Position(rank, file)
                }
            }
        }
        return nil
    }

    /// Returns all positions occupied by pieces of the given color
    func positions(for color: PieceColor) -> [Position] {
        var result: [Position] = []
        for rank in 0..<8 {
            for file in 0..<8 {
                if let piece = self[rank, file], piece.color == color {
                    result.append(Position(rank, file))
                }
            }
        }
        return result
    }
}
