// PieceView.swift
// Renders a chess piece using Unicode symbols

import SwiftUI

struct PieceView: View {
    let piece: Piece
    let size: CGFloat

    var body: some View {
        Text(piece.symbol)
            .font(.system(size: size * 0.75))
            .shadow(color: piece.color == .white ? .black.opacity(0.3) : .white.opacity(0.2),
                    radius: 1, x: 0.5, y: 0.5)
            .frame(width: size, height: size)
    }
}

#Preview {
    HStack {
        PieceView(piece: Piece(.king, .white), size: 64)
        PieceView(piece: Piece(.queen, .black), size: 64)
        PieceView(piece: Piece(.knight, .white), size: 64)
    }
    .padding()
}
