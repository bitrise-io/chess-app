// MoveHistoryView.swift
// Displays the game's move history in algebraic notation

import SwiftUI

struct MoveHistoryView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Move History")
            .font(.headline)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            if viewModel.gameState.moveHistory.isEmpty {
                Text("No moves yet")
                    .foregroundColor(.secondary)
                    .italic()
                    .padding()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Header
                            HStack {
                                Text("#").frame(width: 30, alignment: .leading)
                                Text("White").frame(maxWidth: .infinity, alignment: .leading)
                                Text("Black").frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)

                            Divider()

                            // Move pairs
                            ForEach(movePairs.indices, id: \.self) { idx in
                                let pair = movePairs[idx]
                                MoveRowView(
                                    moveNumber: idx + 1,
                                    whiteMove: pair.0,
                                    blackMove: pair.1,
                                    currentMoveIndex: viewModel.gameState.moveHistory.count - 1
                                )
                                .id(idx)

                                if idx < movePairs.count - 1 {
                                    Divider().padding(.horizontal, 12)
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .onChange(of: viewModel.gameState.moveHistory.count) { _, _ in
                        if let lastIdx = movePairs.indices.last {
                            withAnimation {
                                proxy.scrollTo(lastIdx, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    /// Pair moves into (white, black?) tuples for display
    private var movePairs: [(Move, Move?)] {
        var pairs: [(Move, Move?)] = []
        let moves = viewModel.gameState.moveHistory
        var i = 0
        while i < moves.count {
            let white = moves[i]
            let black = (i + 1 < moves.count) ? moves[i + 1] : nil
            pairs.append((white, black))
            i += 2
        }
        return pairs
    }
}

struct MoveRowView: View {
    let moveNumber: Int
    let whiteMove: Move
    let blackMove: Move?
    let currentMoveIndex: Int

    private var whiteMoveIndex: Int { (moveNumber - 1) * 2 }
    private var blackMoveIndex: Int { (moveNumber - 1) * 2 + 1 }

    var body: some View {
        HStack {
            Text("\(moveNumber).")
                .frame(width: 30, alignment: .leading)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)

            Text(whiteMove.algebraicNotation)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(.body, design: .monospaced))
                .fontWeight(currentMoveIndex == whiteMoveIndex ? .bold : .regular)
                .foregroundColor(currentMoveIndex == whiteMoveIndex ? .primary : .secondary)

            if let black = blackMove {
                Text(black.algebraicNotation)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(currentMoveIndex == blackMoveIndex ? .bold : .regular)
                    .foregroundColor(currentMoveIndex == blackMoveIndex ? .primary : .secondary)
            } else {
                Text("...")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
