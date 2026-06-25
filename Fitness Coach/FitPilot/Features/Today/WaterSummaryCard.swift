//
//  WaterSummaryCard.swift
//  Fitness Coach
//
//  FitPilot AI — Hydration summary card.
//

import SwiftUI

struct WaterSummaryCard: View {
    let summary: WaterSummary
    let canUndoWater: Bool
    let onAddWater: () -> Void
    let onUndoLastWater: () -> Void
    let onLogCustomWater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Water", systemImage: "drop")
                    .font(.headline)
                Spacer()
            }

            Text("\(summary.consumedMl) / \(summary.targetMl) ml")
                .font(.title3.weight(.semibold))

            SwiftUI.ProgressView(value: summary.progress)
                .tint(.cyan)

            Text("\(summary.remainingMl) ml remaining")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Undo last") {
                    onUndoLastWater()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!canUndoWater)

                Button("+500 ml") {
                    onAddWater()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Custom") {
                    onLogCustomWater()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

#Preview {
    WaterSummaryCard(
        summary: TodayPreviewData.state.waterSummary,
        canUndoWater: true,
        onAddWater: {},
        onUndoLastWater: {},
        onLogCustomWater: {}
    )
    .padding()
}
