//
//  WeightTrendChart.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only weight trend chart.
//

import Charts
import SwiftUI

struct WeightTrendChart: View {
    let points: [WeightChartPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Weight Chart", systemImage: "chart.xyaxis.line")
                .font(.headline)

            if points.count < 2 {
                Text("Log your weight for a few days to see your trend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                Chart {
                    ForEach(points) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weightKg)
                        )
                        .foregroundStyle(by: .value("Series", "Weight"))

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weightKg)
                        )
                        .foregroundStyle(by: .value("Series", "Weight"))
                    }

                    ForEach(points.filter { $0.sevenDayAverageKg != nil }) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("7-day average", point.sevenDayAverageKg ?? point.weightKg)
                        )
                        .foregroundStyle(by: .value("Series", "7-day avg"))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    }
                }
                .frame(height: 220)
                .chartYAxisLabel("kg")
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

#Preview {
    WeightTrendChart(points: ProgressPreviewData.state.weightChartPoints)
        .padding()
}
