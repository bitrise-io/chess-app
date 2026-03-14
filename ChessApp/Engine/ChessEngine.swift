// ChessEngine.swift
// Full chess move generation and AI using minimax with alpha-beta pruning

import Foundation

/// Difficulty levels for the AI opponent
enum Difficulty: String, CaseIterable, Codable {
    case beginner     = "Beginner"
    case intermediate = "Intermediate"
    case advanced     = "Advanced"

    var depth: Int {
        switch self {
        case .beginner:     return 2
        case .intermediate: return 3
        case .advanced:     return 4
        }
    }
}

/// The chess engine: move generation and AI
class ChessEngine {

    // MARK: - Piece-Square Tables
    // Values from white's perspective; flip index for black (rank 7 - rank)
    // Tables indexed [rank][file]

    private static let pawnTable: [[Int]] = [
        [  0,  0,  0,  0,  0,  0,  0,  0],
        [ 50, 50, 50, 50, 50, 50, 50, 50],
        [ 10, 10, 20, 30, 30, 20, 10, 10],
        [  5,  5, 10, 25, 25, 10,  5,  5],
        [  0,  0,  0, 20, 20,  0,  0,  0],
        [  5, -5,-10,  0,  0,-10, -5,  5],
        [  5, 10, 10,-20,-20, 10, 10,  5],
        [  0,  0,  0,  0,  0,  0,  0,  0]
    ]

    private static let knightTable: [[Int]] = [
        [-50,-40,-30,-30,-30,-30,-40,-50],
        [-40,-20,  0,  0,  0,  0,-20,-40],
        [-30,  0, 10, 15, 15, 10,  0,-30],
        [-30,  5, 15, 20, 20, 15,  5,-30],
        [-30,  0, 15, 20, 20, 15,  0,-30],
        [-30,  5, 10, 15, 15, 10,  5,-30],
        [-40,-20,  0,  5,  5,  0,-20,-40],
        [-50,-40,-30,-30,-30,-30,-40,-50]
    ]

    private static let bishopTable: [[Int]] = [
        [-20,-10,-10,-10,-10,-10,-10,-20],
        [-10,  0,  0,  0,  0,  0,  0,-10],
        [-10,  0,  5, 10, 10,  5,  0,-10],
        [-10,  5,  5, 10, 10,  5,  5,-10],
        [-10,  0, 10, 10, 10, 10,  0,-10],
        [-10, 10, 10, 10, 10, 10, 10,-10],
        [-10,  5,  0,  0,  0,  0,  5,-10],
        [-20,-10,-10,-10,-10,-10,-10,-20]
    ]

    private static let rookTable: [[Int]] = [
        [  0,  0,  0,  0,  0,  0,  0,  0],
        [  5, 10, 10, 10, 10, 10, 10,  5],
        [ -5,  0,  0,  0,  0,  0,  0, -5],
        [ -5,  0,  0,  0,  0,  0,  0, -5],
        [ -5,  0,  0,  0,  0,  0,  0, -5],
        [ -5,  0,  0,  0,  0,  0,  0, -5],
        [ -5,  0,  0,  0,  0,  0,  0, -5],
        [  0,  0,  0,  5,  5,  0,  0,  0]
    ]

    private static let queenTable: [[Int]] = [
        [-20,-10,-10, -5, -5,-10,-10,-20],
        [-10,  0,  0,  0,  0,  0,  0,-10],
        [-10,  0,  5,  5,  5,  5,  0,-10],
        [ -5,  0,  5,  5,  5,  5,  0, -5],
        [  0,  0,  5,  5,  5,  5,  0, -5],
        [-10,  5,  5,  5,  5,  5,  0,-10],
        [-10,  0,  5,  0,  0,  0,  0,-10],
        [-20,-10,-10, -5, -5,-10,-10,-20]
    ]

    private static let kingMiddleGameTable: [[Int]] = [
        [-30,-40,-40,-50,-50,-40,-40,-30],
        [-30,-40,-40,-50,-50,-40,-40,-30],
        [-30,-40,-40,-50,-50,-40,-40,-30],
        [-30,-40,-40,-50,-50,-40,-40,-30],
        [-20,-30,-30,-40,-40,-30,-30,-20],
        [-10,-20,-20,-20,-20,-20,-20,-10],
        [ 20, 20,  0,  0,  0,  0, 20, 20],
        [ 20, 30, 10,  0,  0, 10, 30, 20]
    ]

    // MARK: - Move Generation

    /// Generate all legal moves for the given color in the given game state
    func generateLegalMoves(for color: PieceColor, in state: GameState) -> [Move] {
        let pseudoLegal = generatePseudoLegalMoves(for: color, in: state)
        return pseudoLegal.filter { move in
            let newBoard = state.board.applying(move)
            return !isInCheck(color: color, board: newBoard)
        }
    }

    /// Generate pseudo-legal moves (may leave own king in check)
    func generatePseudoLegalMoves(for color: PieceColor, in state: GameState) -> [Move] {
        var moves: [Move] = []
        let positions = state.board.positions(for: color)
        for pos in positions {
            guard let piece = state.board[pos] else { continue }
            moves.append(contentsOf: generateMoves(for: piece, at: pos, in: state))
        }
        return moves
    }

    /// Generate moves for a specific piece (pseudo-legal)
    private func generateMoves(for piece: Piece, at pos: Position, in state: GameState) -> [Move] {
        switch piece.type {
        case .pawn:   return generatePawnMoves(piece: piece, at: pos, in: state)
        case .knight: return generateKnightMoves(piece: piece, at: pos, in: state)
        case .bishop: return generateSlidingMoves(piece: piece, at: pos, directions: [(-1,-1),(-1,1),(1,-1),(1,1)], in: state)
        case .rook:   return generateSlidingMoves(piece: piece, at: pos, directions: [(-1,0),(1,0),(0,-1),(0,1)], in: state)
        case .queen:  return generateSlidingMoves(piece: piece, at: pos, directions: [(-1,-1),(-1,1),(1,-1),(1,1),(-1,0),(1,0),(0,-1),(0,1)], in: state)
        case .king:   return generateKingMoves(piece: piece, at: pos, in: state)
        }
    }

    private func generatePawnMoves(piece: Piece, at pos: Position, in state: GameState) -> [Move] {
        var moves: [Move] = []
        let dir = piece.color == .white ? 1 : -1
        let startRank = piece.color == .white ? 1 : 6
        let promoRank = piece.color == .white ? 7 : 0

        // Single push
        let oneStep = Position(pos.rank + dir, pos.file)
        if oneStep.isValid && state.board[oneStep] == nil {
            if oneStep.rank == promoRank {
                // Promotion
                for pt in [PieceType.queen, .rook, .bishop, .knight] {
                    moves.append(Move(from: pos, to: oneStep, piece: piece, moveType: .promotion(pt)))
                }
            } else {
                moves.append(Move(from: pos, to: oneStep, piece: piece, moveType: .normal))

                // Double push from starting rank
                if pos.rank == startRank {
                    let twoStep = Position(pos.rank + 2 * dir, pos.file)
                    if state.board[twoStep] == nil {
                        moves.append(Move(from: pos, to: twoStep, piece: piece, moveType: .normal))
                    }
                }
            }
        }

        // Captures (diagonal)
        for df in [-1, 1] {
            let capPos = Position(pos.rank + dir, pos.file + df)
            guard capPos.isValid else { continue }

            // En passant
            if let epTarget = state.enPassantTarget, capPos == epTarget {
                let capturedPawnPos = Position(pos.rank, capPos.file)
                let capturedPawn = state.board[capturedPawnPos]
                moves.append(Move(from: pos, to: capPos, piece: piece, captured: capturedPawn, moveType: .enPassant))
                continue
            }

            // Normal capture
            if let target = state.board[capPos], target.color != piece.color {
                if capPos.rank == promoRank {
                    for pt in [PieceType.queen, .rook, .bishop, .knight] {
                        moves.append(Move(from: pos, to: capPos, piece: piece, captured: target, moveType: .promotionCapture(pt)))
                    }
                } else {
                    moves.append(Move(from: pos, to: capPos, piece: piece, captured: target, moveType: .capture))
                }
            }
        }

        return moves
    }

    private func generateKnightMoves(piece: Piece, at pos: Position, in state: GameState) -> [Move] {
        var moves: [Move] = []
        let offsets = [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)]
        for (dr, df) in offsets {
            let target = Position(pos.rank + dr, pos.file + df)
            guard target.isValid else { continue }
            if let captured = state.board[target] {
                if captured.color != piece.color {
                    moves.append(Move(from: pos, to: target, piece: piece, captured: captured, moveType: .capture))
                }
            } else {
                moves.append(Move(from: pos, to: target, piece: piece, moveType: .normal))
            }
        }
        return moves
    }

    private func generateSlidingMoves(piece: Piece, at pos: Position, directions: [(Int,Int)], in state: GameState) -> [Move] {
        var moves: [Move] = []
        for (dr, df) in directions {
            var r = pos.rank + dr
            var f = pos.file + df
            while r >= 0 && r < 8 && f >= 0 && f < 8 {
                let target = Position(r, f)
                if let captured = state.board[target] {
                    if captured.color != piece.color {
                        moves.append(Move(from: pos, to: target, piece: piece, captured: captured, moveType: .capture))
                    }
                    break
                } else {
                    moves.append(Move(from: pos, to: target, piece: piece, moveType: .normal))
                }
                r += dr
                f += df
            }
        }
        return moves
    }

    private func generateKingMoves(piece: Piece, at pos: Position, in state: GameState) -> [Move] {
        var moves: [Move] = []
        let offsets = [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)]
        for (dr, df) in offsets {
            let target = Position(pos.rank + dr, pos.file + df)
            guard target.isValid else { continue }
            if let captured = state.board[target] {
                if captured.color != piece.color {
                    moves.append(Move(from: pos, to: target, piece: piece, captured: captured, moveType: .capture))
                }
            } else {
                moves.append(Move(from: pos, to: target, piece: piece, moveType: .normal))
            }
        }

        // Castling
        moves.append(contentsOf: generateCastlingMoves(piece: piece, at: pos, in: state))

        return moves
    }

    private func generateCastlingMoves(piece: Piece, at pos: Position, in state: GameState) -> [Move] {
        var moves: [Move] = []
        let color = piece.color
        let rank = color == .white ? 0 : 7

        // King must be on its starting square
        guard pos == Position(rank, 4) else { return [] }
        // King must not currently be in check
        guard !isInCheck(color: color, board: state.board) else { return [] }

        // Kingside castling
        if state.castlingRights.kingside(for: color) {
            // Squares between king and rook must be empty
            if state.board[rank, 5] == nil && state.board[rank, 6] == nil {
                // King must not pass through or end up in check
                let passThroughBoard = state.board.applying(Move(from: pos, to: Position(rank, 5), piece: piece))
                if !isInCheck(color: color, board: passThroughBoard) {
                    moves.append(Move(from: pos, to: Position(rank, 6), piece: piece, moveType: .castleKingside))
                }
            }
        }

        // Queenside castling
        if state.castlingRights.queenside(for: color) {
            // Squares between king and rook must be empty
            if state.board[rank, 1] == nil && state.board[rank, 2] == nil && state.board[rank, 3] == nil {
                let passThroughBoard = state.board.applying(Move(from: pos, to: Position(rank, 3), piece: piece))
                if !isInCheck(color: color, board: passThroughBoard) {
                    moves.append(Move(from: pos, to: Position(rank, 2), piece: piece, moveType: .castleQueenside))
                }
            }
        }

        return moves
    }

    // MARK: - Check Detection

    /// Returns true if the given color's king is in check
    func isInCheck(color: PieceColor, board: Board) -> Bool {
        guard let kingPos = board.kingPosition(for: color) else { return false }
        return isSquareAttacked(kingPos, by: color.opponent, board: board)
    }

    /// Returns true if a square is attacked by any piece of the given color
    func isSquareAttacked(_ pos: Position, by color: PieceColor, board: Board) -> Bool {
        // Check pawn attacks
        let pawnDir = color == .white ? -1 : 1  // direction pawns of 'color' came from
        for df in [-1, 1] {
            let pawnPos = Position(pos.rank + pawnDir, pos.file + df)
            if pawnPos.isValid, let p = board[pawnPos], p.type == .pawn, p.color == color {
                return true
            }
        }

        // Check knight attacks
        for (dr, df) in [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)] {
            let kPos = Position(pos.rank + dr, pos.file + df)
            if kPos.isValid, let p = board[kPos], p.type == .knight, p.color == color {
                return true
            }
        }

        // Check sliding attacks (bishop, rook, queen)
        // Diagonal (bishop/queen)
        for (dr, df) in [(-1,-1),(-1,1),(1,-1),(1,1)] {
            var r = pos.rank + dr; var f = pos.file + df
            while r >= 0 && r < 8 && f >= 0 && f < 8 {
                if let p = board[r, f] {
                    if p.color == color && (p.type == .bishop || p.type == .queen) { return true }
                    break
                }
                r += dr; f += df
            }
        }

        // Straight (rook/queen)
        for (dr, df) in [(-1,0),(1,0),(0,-1),(0,1)] {
            var r = pos.rank + dr; var f = pos.file + df
            while r >= 0 && r < 8 && f >= 0 && f < 8 {
                if let p = board[r, f] {
                    if p.color == color && (p.type == .rook || p.type == .queen) { return true }
                    break
                }
                r += dr; f += df
            }
        }

        // King attacks
        for (dr, df) in [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)] {
            let kPos = Position(pos.rank + dr, pos.file + df)
            if kPos.isValid, let p = board[kPos], p.type == .king, p.color == color {
                return true
            }
        }

        return false
    }

    // MARK: - Game Status

    func isCheckmate(color: PieceColor, in state: GameState) -> Bool {
        return isInCheck(color: color, board: state.board) &&
               generateLegalMoves(for: color, in: state).isEmpty
    }

    func isStalemate(color: PieceColor, in state: GameState) -> Bool {
        return !isInCheck(color: color, board: state.board) &&
               generateLegalMoves(for: color, in: state).isEmpty
    }

    func hasInsufficientMaterial(in state: GameState) -> Bool {
        var whitePieces: [PieceType] = []
        var blackPieces: [PieceType] = []

        for rank in 0..<8 {
            for file in 0..<8 {
                if let piece = state.board[rank, file] {
                    if piece.color == .white { whitePieces.append(piece.type) }
                    else { blackPieces.append(piece.type) }
                }
            }
        }

        // King vs King
        if whitePieces == [.king] && blackPieces == [.king] { return true }

        // King + minor piece vs King
        let whiteMinors = whitePieces.filter { $0 == .bishop || $0 == .knight }
        let blackMinors = blackPieces.filter { $0 == .bishop || $0 == .knight }

        if whitePieces.count == 1 && blackPieces.count <= 2 && blackMinors.count == blackPieces.count - 1 && whitePieces[0] == .king { return true }
        if blackPieces.count == 1 && whitePieces.count <= 2 && whiteMinors.count == whitePieces.count - 1 && blackPieces[0] == .king { return true }

        // King + bishop vs King + bishop (same color squares) - simplified
        if whitePieces.sorted(by: { $0.rawValue < $1.rawValue }) == [.bishop, .king] &&
           blackPieces.sorted(by: { $0.rawValue < $1.rawValue }) == [.bishop, .king] {
            return true
        }

        return false
    }

    // MARK: - AI: Evaluation

    /// Evaluates the board position in centipawns from white's perspective
    func evaluate(state: GameState) -> Int {
        var score = 0

        for rank in 0..<8 {
            for file in 0..<8 {
                guard let piece = state.board[rank, file] else { continue }
                let tableRank = piece.color == .white ? rank : (7 - rank)
                let positionalBonus = positionBonus(for: piece.type, rank: tableRank, file: file)
                let pieceScore = piece.type.value + positionalBonus
                score += piece.color == .white ? pieceScore : -pieceScore
            }
        }

        return score
    }

    private func positionBonus(for type: PieceType, rank: Int, file: Int) -> Int {
        switch type {
        case .pawn:   return ChessEngine.pawnTable[7 - rank][file]
        case .knight: return ChessEngine.knightTable[7 - rank][file]
        case .bishop: return ChessEngine.bishopTable[7 - rank][file]
        case .rook:   return ChessEngine.rookTable[7 - rank][file]
        case .queen:  return ChessEngine.queenTable[7 - rank][file]
        case .king:   return ChessEngine.kingMiddleGameTable[7 - rank][file]
        }
    }

    // MARK: - AI: Minimax with Alpha-Beta Pruning

    /// Returns the best move for the given color using minimax
    func bestMove(for color: PieceColor, in state: GameState, difficulty: Difficulty) -> Move? {
        let depth = difficulty.depth
        let isMaximizing = color == .white

        var bestMove: Move? = nil
        var bestScore = isMaximizing ? Int.min : Int.max
        let alpha = Int.min
        let beta = Int.max

        let moves = generateLegalMoves(for: color, in: state)
        if moves.isEmpty { return nil }

        // Order moves for better alpha-beta pruning (captures first)
        let orderedMoves = orderMoves(moves)

        for move in orderedMoves {
            var newState = state
            newState.apply(move)
            let score = minimax(state: newState, depth: depth - 1,
                               alpha: alpha, beta: beta,
                               isMaximizing: !isMaximizing)
            if isMaximizing {
                if score > bestScore {
                    bestScore = score
                    bestMove = move
                }
            } else {
                if score < bestScore {
                    bestScore = score
                    bestMove = move
                }
            }
        }

        return bestMove
    }

    private func minimax(state: GameState, depth: Int, alpha: Int, beta: Int, isMaximizing: Bool) -> Int {
        var alpha = alpha
        var beta = beta

        let color: PieceColor = isMaximizing ? .white : .black

        // Terminal conditions
        if isCheckmate(color: color, in: state) {
            return isMaximizing ? -50000 : 50000
        }
        if isStalemate(color: color, in: state) { return 0 }
        if state.isFiftyMoveRule { return 0 }
        if state.isThreefoldRepetition { return 0 }

        if depth == 0 {
            return evaluate(state: state)
        }

        let moves = generateLegalMoves(for: color, in: state)
        if moves.isEmpty { return evaluate(state: state) }

        let orderedMoves = orderMoves(moves)

        if isMaximizing {
            var maxScore = Int.min
            for move in orderedMoves {
                var newState = state
                newState.apply(move)
                let score = minimax(state: newState, depth: depth - 1, alpha: alpha, beta: beta, isMaximizing: false)
                maxScore = max(maxScore, score)
                alpha = max(alpha, score)
                if beta <= alpha { break } // Beta cutoff
            }
            return maxScore
        } else {
            var minScore = Int.max
            for move in orderedMoves {
                var newState = state
                newState.apply(move)
                let score = minimax(state: newState, depth: depth - 1, alpha: alpha, beta: beta, isMaximizing: true)
                minScore = min(minScore, score)
                beta = min(beta, score)
                if beta <= alpha { break } // Alpha cutoff
            }
            return minScore
        }
    }

    /// Orders moves to improve alpha-beta efficiency (captures first, then by piece value)
    private func orderMoves(_ moves: [Move]) -> [Move] {
        return moves.sorted { a, b in
            let aScore = moveOrderScore(a)
            let bScore = moveOrderScore(b)
            return aScore > bScore
        }
    }

    private func moveOrderScore(_ move: Move) -> Int {
        var score = 0
        if let captured = move.captured {
            // MVV-LVA: Most Valuable Victim - Least Valuable Aggressor
            score += captured.type.value - move.piece.type.value / 10
        }
        switch move.moveType {
        case .promotion, .promotionCapture: score += 900
        default: break
        }
        return score
    }
}
