//
//  JourneyWeightTrendSection.swift
//  Fitness Coach
//

import Charts
import SwiftUI

struct JourneyWeightTrendSection: View {
    let state: JourneyWeightTrendState

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            JourneySectionLabel(title: "Weight trend")

            if state.chartPoints.count < 2 {
                Text(state.interpretation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(state.chartPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weightKg)
                        )
                        .foregroundStyle(.primary.opacity(0.8))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weightKg)
                        )
                        .foregroundStyle(.primary)
                        .symbolSize(20)
                    }
                }
                .chartYAxisLabel("kg")
                .chartXAxis(.hidden)
                .frame(height: 120)

                Text(state.interpretation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
