//
//  WaterTrendSummaryCard.swift
//  Fitness Coach
//
//  FitPilot AI — Hydration average summary card.
//

import SwiftUI

struct WaterTrendSummaryCard: View {
    let summary: ProgressWaterSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Hydration", systemImage: "drop")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ProgressMetricCard(
                    title: "Logged days",
                    value: "\(summary.loggedDays)",
                    systemImage: "calendar"
                )
                ProgressMetricCard(
                    title: "Average water",
                    value: ProgressFormatter.ml(summary.averageWaterMl),
                    systemImage: "drop.fill"
                )
                ProgressMetricCard(
                    title: "Average target",
                    value: ProgressFormatter.ml(summary.averageWaterTargetMl),
                    systemImage: "target"
                )
                ProgressMetricCard(
                    title: "Consistency",
                    value: ProgressFormatter.percent(summary.consistencyPercent),
                    subtitle: "Days at 80%+ target",
                    systemImage: "checkmark.circle"
                )
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

#Preview {
    WaterTrendSummaryCard(summary: ProgressPreviewData.state.waterSummary)
        .padding()
}
