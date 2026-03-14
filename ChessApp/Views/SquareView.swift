// SquareView.swift
// Renders a single chess board square with highlights and piece

import SwiftUI

struct SquareView: View {
    let position: Position
    let piece: Piece?
    let squareSize: CGFloat
    let isSelected: Bool
    let isLegalDestination: Bool
    let isLastMoveSquare: Bool
    let isInCheck: Bool

    // Colors
    private var baseColor: Color {
        let isLight = (position.rank + position.file) % 2 == 1
        return isLight ? Color(red: 0.93, green: 0.87, blue: 0.75) : Color(red: 0.45, green: 0.28, blue: 0.15)
    }

    private var overlayColor: Color? {
        if isInCheck { return .red.opacity(0.5) }
        if isSelected { return .blue.opacity(0.4) }
        if isLastMoveSquare { return .yellow.opacity(0.4) }
        return nil
    }

    var body: some View {
        ZStack {
            // Base square color
            baseColor

            // Highlight overlay
            if let overlay = overlayColor {
                overlay
            }

            // Legal move indicator
            if isLegalDestination {
                if piece != nil {
                    // Capture indicator: ring around the square
                    Circle()
                        .stroke(Color.green.opacity(0.7), lineWidth: squareSize * 0.08)
                        .padding(squareSize * 0.04)
                } else {
                    // Move indicator: dot in center
                    Circle()
                        .fill(Color.green.opacity(0.5))
                        .frame(width: squareSize * 0.3, height: squareSize * 0.3)
                }
            }

            // Chess piece
            if let piece = piece {
                PieceView(piece: piece, size: squareSize)
            }
        }
        .frame(width: squareSize, height: squareSize)
    }
}
