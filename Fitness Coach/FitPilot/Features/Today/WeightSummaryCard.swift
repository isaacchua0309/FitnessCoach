//
//  WeightSummaryCard.swift
//  Fitness Coach
//
//  FitPilot AI — Today weight summary card.
//

import SwiftUI

struct WeightSummaryCard: View {
    let summary: TodayWeightSummary
    let onLogWeight: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "scalemass")
                .font(.title2)
                .foregroundStyle(.purple)
                .frame(width: 44, height: 44)
                .background(.purple.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Weight")
                    .font(.headline)
                Text(summary.displayText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Log", action: onLogWeight)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

#Preview {
    WeightSummaryCard(summary: TodayPreviewData.state.weightSummary) {}
        .padding()
}
