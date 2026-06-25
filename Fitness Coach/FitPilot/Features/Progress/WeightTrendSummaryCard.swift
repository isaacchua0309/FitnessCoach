//
//  WeightTrendSummaryCard.swift
//  Fitness Coach
//
//  FitPilot AI — Weight trend summary card.
//

import SwiftUI

struct WeightTrendSummaryCard: View {
    let summary: ProgressWeightSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Weight Trend", systemImage: "scalemass")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ProgressMetricCard(
                    title: "Latest",
                    value: ProgressFormatter.kg(summary.latestWeightKg),
                    systemImage: "circle.fill"
                )
                ProgressMetricCard(
                    title: "7-day average",
                    value: ProgressFormatter.kg(summary.sevenDayAverageKg),
                    systemImage: "calendar"
                )
                ProgressMetricCard(
                    title: "Change",
                    value: ProgressFormatter.kgChange(summary.changeKg),
                    systemImage: "arrow.up.and.down"
                )
                ProgressMetricCard(
                    title: "Direction",
                    value: ProgressFormatter.trendDirection(summary.direction),
                    subtitle: summary.hasSuddenSpike ? "Sudden spike detected" : nil,
                    systemImage: "chart.line.uptrend.xyaxis"
                )
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

#Preview {
    WeightTrendSummaryCard(summary: ProgressPreviewData.state.weightSummary)
        .padding()
}
