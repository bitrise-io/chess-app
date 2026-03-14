// BoardView.swift
// The main chess board view with click-to-move and drag-and-drop

import SwiftUI

struct BoardView: View {
    @ObservedObject var viewModel: GameViewModel

    // Drag state
    @State private var draggedPiece: Piece? = nil
    @State private var dragFromPosition: Position? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var squareSize: CGFloat = 64

    // Engine for check detection display
    private let engine = ChessEngine()

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let sq = size / 8

            ZStack {
                // Board grid
                boardGrid(squareSize: sq)
                    .frame(width: size, height: size)

                // Rank/file labels
                rankFileLabels(squareSize: sq, totalSize: size)

                // Dragging piece overlay
                if let piece = draggedPiece {
                    PieceView(piece: piece, size: sq)
                        .position(dragLocation)
                        .allowsHitTesting(false)
                        .zIndex(100)
                }
            }
            .onAppear { squareSize = sq }
            .onChange(of: geometry.size) { _, newSize in
                squareSize = min(newSize.width, newSize.height) / 8
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func boardGrid(squareSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(viewModel.displayRanks, id: \.self) { rank in
                HStack(spacing: 0) {
                    ForEach(viewModel.displayFiles, id: \.self) { file in
                        let pos = Position(rank, file)
                        let piece = viewModel.gameState.board[pos]
                        let isSelected = viewModel.selectedSquare == pos
                        let isLegal = viewModel.legalMovesForSelected.contains { $0.to == pos }
                        let isLastMove = viewModel.lastMove.map { $0.from == pos || $0.to == pos } ?? false
                        let isKingInCheck = isKingCheckSquare(pos)

                        SquareView(
                            position: pos,
                            piece: (dragFromPosition == pos) ? nil : piece,
                            squareSize: squareSize,
                            isSelected: isSelected,
                            isLegalDestination: isLegal,
                            isLastMoveSquare: isLastMove,
                            isInCheck: isKingInCheck
                        )
                        .gesture(
                            DragGesture(minimumDistance: 5, coordinateSpace: .global)
                                .onChanged { value in
                                    handleDragChanged(value, from: pos, squareSize: squareSize)
                                }
                                .onEnded { value in
                                    handleDragEnded(value, squareSize: squareSize)
                                }
                        )
                        .onTapGesture {
                            viewModel.selectSquare(at: pos)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rankFileLabels(squareSize: CGFloat, totalSize: CGFloat) -> some View {
        // Rank numbers (1-8 on left side)
        VStack(spacing: 0) {
            ForEach(viewModel.displayRanks, id: \.self) { rank in
                HStack {
                    Text("\(rank + 1)")
                        .font(.system(size: squareSize * 0.2, weight: .medium))
                        .foregroundColor((rank + 0) % 2 == 0 ?
                            Color(red: 0.93, green: 0.87, blue: 0.75) :
                            Color(red: 0.45, green: 0.28, blue: 0.15))
                        .frame(width: squareSize * 0.25, height: squareSize)
                        .padding(.leading, 2)
                    Spacer()
                }
                .frame(width: squareSize, height: squareSize)
            }
        }
        .frame(width: totalSize, height: totalSize, alignment: .leading)
        .allowsHitTesting(false)

        // File letters (a-h on bottom)
        HStack(spacing: 0) {
            ForEach(viewModel.displayFiles, id: \.self) { file in
                VStack {
                    Spacer()
                    Text(String(UnicodeScalar(UInt8(file) + 97)))
                        .font(.system(size: squareSize * 0.2, weight: .medium))
                        .foregroundColor((file + 1) % 2 == 0 ?
                            Color(red: 0.93, green: 0.87, blue: 0.75) :
                            Color(red: 0.45, green: 0.28, blue: 0.15))
                        .frame(height: squareSize * 0.25)
                        .padding(.bottom, 2)
                }
                .frame(width: squareSize, height: squareSize)
            }
        }
        .frame(width: totalSize, height: totalSize, alignment: .bottom)
        .allowsHitTesting(false)
    }

    // MARK: - Drag Handling

    private func handleDragChanged(_ value: DragGesture.Value, from pos: Position, squareSize: CGFloat) {
        if dragFromPosition == nil {
            // Start drag
            if let piece = viewModel.gameState.board[pos], piece.color == viewModel.gameState.activeColor {
                dragFromPosition = pos
                draggedPiece = piece
                viewModel.selectedSquare = pos
                viewModel.legalMovesForSelected = ChessEngine().generateLegalMoves(
                    for: viewModel.gameState.activeColor, in: viewModel.gameState)
                    .filter { $0.from == pos }
            }
        }
        dragLocation = value.location
    }

    private func handleDragEnded(_ value: DragGesture.Value, squareSize: CGFloat) {
        guard let fromPos = dragFromPosition else { return }

        // Convert drop location to board position
        if let toPos = boardPosition(from: value.location, squareSize: squareSize) {
            viewModel.dragPiece(from: fromPos, to: toPos)
        }

        dragFromPosition = nil
        draggedPiece = nil
        viewModel.selectedSquare = nil
        viewModel.legalMovesForSelected = []
    }

    /// Convert a screen coordinate to a board Position
    private func boardPosition(from point: CGPoint, squareSize: CGFloat) -> Position? {
        // Find which square the point is in based on displayed grid
        let ranks = viewModel.displayRanks
        let files = viewModel.displayFiles

        let col = Int(point.x / squareSize)
        let row = Int(point.y / squareSize)

        guard row >= 0 && row < 8 && col >= 0 && col < 8 else { return nil }
        return Position(ranks[row], files[col])
    }

    private func isKingCheckSquare(_ pos: Position) -> Bool {
        guard let piece = viewModel.gameState.board[pos],
              piece.type == .king else { return false }
        return engine.isInCheck(color: piece.color, board: viewModel.gameState.board)
    }
}
