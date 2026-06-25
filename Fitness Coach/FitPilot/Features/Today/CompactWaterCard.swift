//
//  CompactWaterCard.swift
//  Fitness Coach
//
//  FitPilot AI — Compact water metric with logging menu.
//

import SwiftUI

struct CompactWaterCard: View {
    let summary: WaterSummary
    let canUndoWater: Bool
    let onAddWater: () -> Void
    let onUndoLastWater: () -> Void
    let onLogCustomWater: () -> Void

    var body: some View {
        Menu {
            Button("+500 ml", action: onAddWater)
            Button("Custom amount...", action: onLogCustomWater)
            if canUndoWater {
                Button("Undo last entry", role: .destructive, action: onUndoLastWater)
            }
        } label: {
            CompactMetricCard(
                icon: "drop.fill",
                iconColor: .cyan,
                title: "Water",
                value: "\(summary.consumedMl) / \(summary.targetMl) ml",
                actionTitle: "Log",
                action: nil
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CompactWaterCard(
        summary: TodayPreviewData.state.waterSummary,
        canUndoWater: true,
        onAddWater: {},
        onUndoLastWater: {},
        onLogCustomWater: {}
    )
    .padding()
}
