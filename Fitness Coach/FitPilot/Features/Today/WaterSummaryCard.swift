//
//  WaterSummaryCard.swift
//  Fitness Coach
//
//  FitPilot AI — Hydration summary card.
//

import SwiftUI

struct WaterSummaryCard: View {
    let summary: WaterSummary
    let onAddWater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Water", systemImage: "drop")
                    .font(.headline)
                Spacer()
                Button("+500 ml", action: onAddWater)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }

            Text("\(summary.consumedMl) / \(summary.targetMl) ml")
                .font(.title3.weight(.semibold))

            ProgressView(value: summary.progress)
                .tint(.cyan)

            Text("\(summary.remainingMl) ml remaining")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

#Preview {
    WaterSummaryCard(summary: TodayPreviewData.state.waterSummary) {}
        .padding()
}
