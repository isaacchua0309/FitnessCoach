//
//  JourneyDetailedAnalyticsSection.swift
//  Fitness Coach
//

import Charts
import SwiftUI

struct JourneyDetailedAnalyticsSection: View {
    let analytics: ProgressAnalyticsDetail
    let selectedRangeDays: Int
    let onSelectRange: (Int) -> Void

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: JourneyLayout.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Range")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressRangeSelector(
                        selectedRangeDays: selectedRangeDays,
                        onSelect: onSelectRange
                    )
                }

                if analytics.weightChartPoints.count >= 2 {
                    analyticsBlock(title: "Weight") {
                        Chart {
                            ForEach(analytics.weightChartPoints) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Weight", point.weightKg)
                                )
                                .foregroundStyle(.primary.opacity(0.7))
                            }
                        }
                        .frame(height: 100)
                    }
                }

                analyticsBlock(title: "Nutrition") {
                    analyticsRow("Logged days", "\(analytics.nutritionSummary.loggedDays)")
                    analyticsRow("Avg calories", ProgressFormatter.kcal(analytics.nutritionSummary.averageCalories))
                    analyticsRow("Avg protein", ProgressFormatter.grams(analytics.nutritionSummary.averageProtein))
                    analyticsRow("Avg carbs", ProgressFormatter.grams(analytics.nutritionSummary.averageCarbs))
                    analyticsRow("Avg fat", ProgressFormatter.grams(analytics.nutritionSummary.averageFat))
                }

                analyticsBlock(title: "Water") {
                    analyticsRow("Avg water", ProgressFormatter.ml(analytics.waterSummary.averageWaterMl))
                    analyticsRow("Avg target", ProgressFormatter.ml(analytics.waterSummary.averageWaterTargetMl))
                    analyticsRow("Consistency", ProgressFormatter.percent(analytics.waterSummary.consistencyPercent))
                }

                if let workout = analytics.workoutSummary {
                    analyticsBlock(title: "Training") {
                        analyticsRow("Workouts", "\(workout.workoutCount)")
                        analyticsRow("Calories burned", ProgressFormatter.kcal(workout.totalEstimatedCaloriesBurned))
                        if let duration = workout.averageDurationMinutes {
                            analyticsRow("Avg duration", "\(duration) min")
                        }
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            Text("Detailed analytics")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.top, 8)
    }

    private func analyticsBlock(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func analyticsRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
