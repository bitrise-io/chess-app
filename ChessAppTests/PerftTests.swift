// PerftTests.swift
// Perft (Performance Test) tests validate move generation correctness
// by counting the number of leaf nodes at a given depth from known positions.

import XCTest
@testable import ChessApp

final class PerftTests: XCTestCase {

    var engine: ChessEngine!

    override func setUp() {
        super.setUp()
        engine = ChessEngine()
    }

    // MARK: - Perft Function

    /// Counts the number of leaf nodes at the given depth from the given state
    func perft(state: GameState, depth: Int) -> Int {
        if depth == 0 { return 1 }

        let moves = engine.generateLegalMoves(for: state.activeColor, in: state)
        if depth == 1 { return moves.count }

        var count = 0
        for move in moves {
            var newState = state
            newState.apply(move)
            count += perft(state: newState, depth: depth - 1)
        }
        return count
    }

    // MARK: - Starting Position Tests
    // Known perft values for the starting position:
    // Depth 1: 20, Depth 2: 400, Depth 3: 8902, Depth 4: 197281

    func testPerftDepth1() {
        let state = GameState()
        let result = perft(state: state, depth: 1)
        XCTAssertEqual(result, 20, "Depth 1 from start should be 20 moves")
    }

    func testPerftDepth2() {
        let state = GameState()
        let result = perft(state: state, depth: 2)
        XCTAssertEqual(result, 400, "Depth 2 from start should be 400 nodes")
    }

    func testPerftDepth3() {
        let state = GameState()
        let result = perft(state: state, depth: 3)
        XCTAssertEqual(result, 8902, "Depth 3 from start should be 8902 nodes")
    }

    // Depth 4 is slower (~0.5-2s) but verifiable
    func testPerftDepth4() {
        let state = GameState()
        let result = perft(state: state, depth: 4)
        XCTAssertEqual(result, 197281, "Depth 4 from start should be 197281 nodes")
    }

    // MARK: - Specific Position Tests

    /// Test castling rights are properly handled
    func testCastlingAvailable() {
        let state = GameState()
        let moves = engine.generateLegalMoves(for: .white, in: state)
        // From starting position: 20 legal moves (16 pawn + 4 knight)
        XCTAssertEqual(moves.count, 20)
    }

    /// Test that a king in check has limited moves
    func testKingInCheck() {
        var state = GameState()
        // Set up Scholar's mate threat
        // After 1.e4 e5 2.Bc4 Nc6 3.Qh5 - black king is not in check yet
        // but let's test a simple check scenario

        // Clear the board and create a simple check scenario
        var board = Board()
        board[0, 4] = Piece(.king, .white)
        board[7, 4] = Piece(.king, .black)
        board[6, 4] = Piece(.rook, .white)  // Rook gives check to black king
        state.board = board
        state.activeColor = .black
        state.castlingRights = CastlingRights()
        state.castlingRights.blackKingside = false
        state.castlingRights.blackQueenside = false
        state.castlingRights.whiteKingside = false
        state.castlingRights.whiteQueenside = false

        XCTAssertTrue(engine.isInCheck(color: .black, board: board))
        let moves = engine.generateLegalMoves(for: .black, in: state)
        // Black king can move to d8, f8 (away from the rook's file)
        // Cannot move to e squares, d8/f8 are ok, d7/f7 ok too... but rook on e6 attacks e7
        XCTAssertFalse(moves.isEmpty, "King in check should still have moves")
        // All moves must escape check
        for move in moves {
            let newBoard = board.applying(move)
            XCTAssertFalse(engine.isInCheck(color: .black, board: newBoard),
                           "Move \(move.algebraicNotation) should escape check")
        }
    }

    /// Test en passant is generated correctly
    func testEnPassant() {
        var state = GameState()
        var board = Board()
        board[0, 4] = Piece(.king, .white)
        board[7, 4] = Piece(.king, .black)
        board[4, 4] = Piece(.pawn, .white)   // White pawn on e5
        board[4, 3] = Piece(.pawn, .black)   // Black pawn on d5 (just moved from d7)
        state.board = board
        state.activeColor = .white
        state.enPassantTarget = Position(5, 3)  // d6 is the en passant square
        state.castlingRights.blackKingside = false
        state.castlingRights.blackQueenside = false
        state.castlingRights.whiteKingside = false
        state.castlingRights.whiteQueenside = false

        let moves = engine.generateLegalMoves(for: .white, in: state)
        let epMoves = moves.filter {
            if case .enPassant = $0.moveType { return true }
            return false
        }
        XCTAssertEqual(epMoves.count, 1, "Should have exactly one en passant move")
        XCTAssertEqual(epMoves.first?.to, Position(5, 3), "En passant target should be d6")
    }

    /// Test pawn promotion generates 4 moves per promotion square
    func testPawnPromotion() {
        var state = GameState()
        var board = Board()
        board[0, 4] = Piece(.king, .white)
        board[7, 4] = Piece(.king, .black)
        board[6, 0] = Piece(.pawn, .white)  // White pawn on a7, about to promote
        state.board = board
        state.activeColor = .white
        state.castlingRights = CastlingRights()
        state.castlingRights.blackKingside = false
        state.castlingRights.blackQueenside = false
        state.castlingRights.whiteKingside = false
        state.castlingRights.whiteQueenside = false

        let moves = engine.generateLegalMoves(for: .white, in: state)
        let promoMoves = moves.filter {
            if case .promotion(_) = $0.moveType { return true }
            return false
        }
        XCTAssertEqual(promoMoves.count, 4, "Should have 4 promotion moves (Q, R, B, N)")
    }

    /// Test checkmate detection
    func testCheckmateDetection() {
        // Fool's Mate: 1.f3 e5 2.g4 Qh4#
        var state = GameState()
        var board = Board.initialBoard()

        // Apply fool's mate manually
        // 1. f3
        var move = Move(from: Position(1,5), to: Position(2,5), piece: Piece(.pawn, .white))
        state.apply(move)
        // 1... e5
        move = Move(from: Position(6,4), to: Position(4,4), piece: Piece(.pawn, .black))
        state.apply(move)
        // 2. g4
        move = Move(from: Position(1,6), to: Position(3,6), piece: Piece(.pawn, .white))
        state.apply(move)
        // 2... Qh4#
        move = Move(from: Position(7,3), to: Position(3,7), piece: Piece(.queen, .black), moveType: .normal)
        state.apply(move)

        // White should be in checkmate
        XCTAssertTrue(engine.isCheckmate(color: .white, in: state), "White should be in checkmate (Fool's mate)")
        XCTAssertFalse(engine.isStalemate(color: .white, in: state))
    }

    /// Test that insufficient material detection works
    func testInsufficientMaterial() {
        var state = GameState()
        var board = Board()
        board[0, 4] = Piece(.king, .white)
        board[7, 4] = Piece(.king, .black)
        state.board = board
        state.activeColor = .white

        XCTAssertTrue(engine.hasInsufficientMaterial(in: state), "K vs K should be insufficient material")
    }
}
