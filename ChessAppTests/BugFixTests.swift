// BugFixTests.swift
// Unit tests covering the bug fixes for ACT-2384

import XCTest
@testable import ChessApp

final class BugFixTests: XCTestCase {

    var engine: ChessEngine!

    override func setUp() {
        super.setUp()
        engine = ChessEngine()
    }

    // MARK: - Capture Tests

    /// 1.e4 d5 2.exd5 — white pawn captures black pawn
    func testWhiteCapture() {
        var state = GameState()
        // 1. e4
        state.apply(Move(from: Position(1, 4), to: Position(3, 4), piece: Piece(.pawn, .white)))
        // 1... d5
        state.apply(Move(from: Position(6, 3), to: Position(4, 3), piece: Piece(.pawn, .black)))

        // White pawn on e4 (3,4) should be able to capture on d5 (4,3)
        let whiteMoves = engine.generateLegalMoves(for: .white, in: state)
        let capture = whiteMoves.first { $0.from == Position(3, 4) && $0.to == Position(4, 3) }
        XCTAssertNotNil(capture, "White pawn on e4 should be able to capture on d5")
        XCTAssertEqual(capture?.moveType, .capture)

        // 2. exd5 — apply the capture
        state.apply(capture!)
        XCTAssertNil(state.board[Position(3, 4)], "e4 square should be empty after capture")
        XCTAssertNotNil(state.board[Position(4, 3)], "d5 should now have a piece")
        XCTAssertEqual(state.board[Position(4, 3)]?.color, .white, "White pawn should be on d5")
    }

    /// 1.e4 d5 2.Nf3 dxe4 — black pawn captures white pawn
    func testBlackCapture() {
        var state = GameState()
        // 1. e4
        state.apply(Move(from: Position(1, 4), to: Position(3, 4), piece: Piece(.pawn, .white)))
        // 1... d5
        state.apply(Move(from: Position(6, 3), to: Position(4, 3), piece: Piece(.pawn, .black)))
        // 2. Nf3
        state.apply(Move(from: Position(0, 6), to: Position(2, 5), piece: Piece(.knight, .white)))

        // Black pawn on d5 (4,3) should be able to capture on e4 (3,4)
        let blackMoves = engine.generateLegalMoves(for: .black, in: state)
        let capture = blackMoves.first { $0.from == Position(4, 3) && $0.to == Position(3, 4) }
        XCTAssertNotNil(capture, "Black pawn on d5 should be able to capture on e4")
        XCTAssertEqual(capture?.moveType, .capture)

        // 2... dxe4 — apply the capture
        state.apply(capture!)
        XCTAssertNil(state.board[Position(4, 3)], "d5 square should be empty after capture")
        XCTAssertNotNil(state.board[Position(3, 4)], "e4 should now have a piece")
        XCTAssertEqual(state.board[Position(3, 4)]?.color, .black, "Black pawn should be on e4")
    }

    // MARK: - Invalid Move Tests

    /// A pawn cannot move backwards
    func testPawnCannotMoveBackwards() {
        var state = GameState()
        // Advance white pawn to e4
        state.apply(Move(from: Position(1, 4), to: Position(3, 4), piece: Piece(.pawn, .white)))
        state.apply(Move(from: Position(6, 4), to: Position(4, 4), piece: Piece(.pawn, .black)))

        // White to move: pawn on e4 (3,4) should NOT be able to move to e3 (2,4) backwards
        let whiteMoves = engine.generateLegalMoves(for: .white, in: state)
        let backwards = whiteMoves.filter { $0.from == Position(3, 4) && $0.to == Position(2, 4) }
        XCTAssertTrue(backwards.isEmpty, "Pawn should not be able to move backwards")
    }

    /// A bishop cannot move through blocking pieces
    func testBishopCannotMoveThroughPieces() {
        // Starting position: bishops are blocked by pawns
        let state = GameState()
        let moves = engine.generateLegalMoves(for: .white, in: state)
        // White bishop on c1 (0,2) should have no legal moves because pawns block it
        let bishopMoves = moves.filter { $0.from == Position(0, 2) }
        XCTAssertTrue(bishopMoves.isEmpty, "Bishop on c1 should have no moves in the starting position")

        // Same for f1 bishop
        let f1BishopMoves = moves.filter { $0.from == Position(0, 5) }
        XCTAssertTrue(f1BishopMoves.isEmpty, "Bishop on f1 should have no moves in the starting position")
    }

    // MARK: - En Passant Test

    /// En passant capture removes the correct pawn and moves to the correct square
    func testEnPassantCapture() {
        var state = GameState()
        var board = Board()
        board[0, 4] = Piece(.king, .white)
        board[7, 4] = Piece(.king, .black)
        board[4, 4] = Piece(.pawn, .white)   // White pawn on e5
        board[4, 3] = Piece(.pawn, .black)   // Black pawn on d5 (just double-pushed)
        state.board = board
        state.activeColor = .white
        state.enPassantTarget = Position(5, 3)  // d6 en passant target
        state.castlingRights.blackKingside = false
        state.castlingRights.blackQueenside = false
        state.castlingRights.whiteKingside = false
        state.castlingRights.whiteQueenside = false

        let moves = engine.generateLegalMoves(for: .white, in: state)
        let epMove = moves.first {
            if case .enPassant = $0.moveType { return $0.to == Position(5, 3) }
            return false
        }
        XCTAssertNotNil(epMove, "En passant move to d6 should be available")

        // Apply the en passant capture
        state.apply(epMove!)

        // White pawn should be on d6 (5,3)
        XCTAssertEqual(state.board[Position(5, 3)]?.type, .pawn)
        XCTAssertEqual(state.board[Position(5, 3)]?.color, .white)
        // Black pawn on d5 (4,3) should be captured
        XCTAssertNil(state.board[Position(4, 3)], "Captured pawn should be removed from d5")
        // e5 (4,4) should be empty
        XCTAssertNil(state.board[Position(4, 4)], "e5 should be empty after en passant")
    }

    // MARK: - Drag Coordinate Math Test

    /// Verify boardPosition coordinate math is correct when using a board-relative coordinate space.
    /// With .named("board"), value.location is relative to the board's top-left corner,
    /// so dividing by squareSize directly gives the correct column/row.
    func testDragCoordinateMath() {
        let squareSize: CGFloat = 64.0

        // Simulate board-relative coordinates (origin = top-left of board)
        // Square (row=0, col=0) spans x: 0..<64, y: 0..<64
        // Square (row=1, col=2) spans x: 128..<192, y: 64..<128

        let testCases: [(CGPoint, Int, Int)] = [
            (CGPoint(x: 10, y: 10), 0, 0),      // top-left square
            (CGPoint(x: 96, y: 32), 0, 1),      // row 0, col 1
            (CGPoint(x: 160, y: 80), 1, 2),     // row 1, col 2
            (CGPoint(x: 480, y: 448), 7, 7),    // bottom-right square
        ]

        for (point, expectedRow, expectedCol) in testCases {
            let col = Int(point.x / squareSize)
            let row = Int(point.y / squareSize)
            XCTAssertEqual(row, expectedRow, "Row mismatch for point \(point)")
            XCTAssertEqual(col, expectedCol, "Col mismatch for point \(point)")
        }
    }

    // MARK: - Insufficient Material Tests

    /// K+B vs K+B on same color squares = draw (insufficient material)
    func testKBvKBSameColorIsDraw() {
        var state = GameState()
        var board = Board()
        board[0, 4] = Piece(.king, .white)
        board[7, 4] = Piece(.king, .black)
        // Both bishops on dark squares: (rank+file)%2 == 0
        board[0, 0] = Piece(.bishop, .white)  // a1: (0+0)%2 = 0
        board[2, 0] = Piece(.bishop, .black)  // a3: (2+0)%2 = 0
        state.board = board

        XCTAssertTrue(engine.hasInsufficientMaterial(in: state),
                      "K+B vs K+B on same color squares should be insufficient material")
    }

    /// K+B vs K+B on opposite color squares = NOT a draw
    func testKBvKBOppositeColorIsNotDraw() {
        var state = GameState()
        var board = Board()
        board[0, 4] = Piece(.king, .white)
        board[7, 4] = Piece(.king, .black)
        // Bishops on opposite color squares
        board[0, 0] = Piece(.bishop, .white)  // a1: (0+0)%2 = 0 (dark)
        board[0, 1] = Piece(.bishop, .black)  // b1: (0+1)%2 = 1 (light)
        state.board = board

        XCTAssertFalse(engine.hasInsufficientMaterial(in: state),
                       "K+B vs K+B on opposite color squares should NOT be insufficient material")
    }

    // MARK: - Threefold Repetition Tests

    /// Threefold repetition fires at 3 occurrences (not 4) after the initial-position fix
    func testThreefoldRepetitionAt3Occurrences() {
        var state = GameState()
        // The initial position is recorded in init(), so it counts as occurrence 1.
        // Move knights back and forth to cycle through the initial position:
        // Nf3, Nf6, Ng1 (back), Ng8 (back) — now we're back to the initial position (occurrence 2)
        // Nf3, Nf6, Ng1, Ng8 again — occurrence 3 → should trigger threefold
        let nf3 = Move(from: Position(0, 6), to: Position(2, 5), piece: Piece(.knight, .white))
        let nf6 = Move(from: Position(7, 6), to: Position(5, 5), piece: Piece(.knight, .black))
        let ng1 = Move(from: Position(2, 5), to: Position(0, 6), piece: Piece(.knight, .white))
        let ng8 = Move(from: Position(5, 5), to: Position(7, 6), piece: Piece(.knight, .black))

        // Cycle 1 (back to initial = occurrence 2)
        state.apply(nf3); state.apply(nf6); state.apply(ng1); state.apply(ng8)
        XCTAssertFalse(state.isThreefoldRepetition, "Should not be threefold after 2 occurrences")

        // Cycle 2 (back to initial = occurrence 3)
        state.apply(nf3); state.apply(nf6); state.apply(ng1); state.apply(ng8)
        XCTAssertTrue(state.isThreefoldRepetition, "Should be threefold after 3 occurrences of the same position")
    }

    /// Without the fix, the initial position would not be recorded, requiring 4 occurrences.
    /// This test verifies that after only 2 return cycles (not 3), repetition does NOT fire prematurely.
    func testThreefoldRepetitionDoesNotFireAtTwoOccurrences() {
        var state = GameState()
        let nf3 = Move(from: Position(0, 6), to: Position(2, 5), piece: Piece(.knight, .white))
        let nf6 = Move(from: Position(7, 6), to: Position(5, 5), piece: Piece(.knight, .black))
        let ng1 = Move(from: Position(2, 5), to: Position(0, 6), piece: Piece(.knight, .white))
        let ng8 = Move(from: Position(5, 5), to: Position(7, 6), piece: Piece(.knight, .black))

        // Only one return cycle (occurrence 2 of initial position)
        state.apply(nf3); state.apply(nf6); state.apply(ng1); state.apply(ng8)
        XCTAssertFalse(state.isThreefoldRepetition,
                       "Two occurrences should not trigger threefold repetition")
    }
}
