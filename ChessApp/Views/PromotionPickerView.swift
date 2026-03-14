// PromotionPickerView.swift
// Shows a dialog to choose a promotion piece

import SwiftUI

struct PromotionPickerView: View {
    let color: PieceColor
    let onSelect: (PieceType) -> Void

    private let choices: [PieceType] = [.queen, .rook, .bishop, .knight]

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose Promotion Piece")
                .font(.headline)
                .padding(.top)

            HStack(spacing: 20) {
                ForEach(choices, id: \.rawValue) { pieceType in
                    Button {
                        onSelect(pieceType)
                    } label: {
                        VStack(spacing: 6) {
                            Text(Piece(pieceType, color).symbol)
                                .font(.system(size: 48))
                            Text(pieceType.name)
                                .font(.caption)
                        }
                        .frame(width: 72, height: 80)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                        .shadow(radius: 3)
                    }
                    .buttonStyle(.plain)
                    .hoverEffect()
                }
            }
            .padding()
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(16)
        .shadow(radius: 20)
    }
}

// Simple hover effect modifier for macOS
struct HoverEffect: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in isHovered = hovering }
    }
}

extension View {
    func hoverEffect() -> some View {
        modifier(HoverEffect())
    }
}
