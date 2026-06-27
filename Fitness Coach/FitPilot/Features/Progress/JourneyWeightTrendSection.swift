//
//  JourneyWeightTrendSection.swift
//  Fitness Coach
//

import Charts
import SwiftUI

struct JourneyWeightTrendSection: View {
    let state: JourneyWeightTrendState
    var onLogWeight: (() -> Void)?

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            JourneySectionLabel(title: "Weight trend")

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    if state.chartPoints.count < 2 {
                        Text(emptyStateMessage)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let onLogWeight {
                            Button(FormaProductCopy.Journey.logWeightWithCoach, action: onLogWeight)
                                .buttonStyle(.bordered)
                                .tint(FormaTokens.Color.accent)
                        }
                    } else {
                        Chart {
                            ForEach(state.chartPoints) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Weight", point.weightKg)
                                )
                                .foregroundStyle(FormaTokens.Color.accent.opacity(0.8))
                                .interpolationMethod(.catmullRom)

                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Weight", point.weightKg)
                                )
                                .foregroundStyle(FormaTokens.Color.accent)
                                .symbolSize(20)
                            }
                        }
                        .chartYAxisLabel("kg")
                        .chartXAxis(.hidden)
                        .frame(minHeight: chartHeight)

                        Text(state.interpretation)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var emptyStateMessage: String {
        state.interpretation == FormaProductCopy.Journey.weightTrendEmpty
            ? FormaProductCopy.Journey.weightTrendEmpty
            : state.interpretation
    }
}
