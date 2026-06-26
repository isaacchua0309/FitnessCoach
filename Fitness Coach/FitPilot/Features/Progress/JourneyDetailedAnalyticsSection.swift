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
        FitPilotPlanCard {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: JourneyLayout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                        Text("Range")
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
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
                                    .foregroundStyle(FormaTokens.Color.accent.opacity(0.7))
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
                .padding(.top, FormaTokens.Spacing.sm)
            } label: {
                Text("Detailed analytics")
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
            }
            .tint(FormaTokens.Color.accent)
        }
    }

    private func analyticsBlock(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            FormaSectionLabel(title: title)
            content()
        }
    }

    private func analyticsRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
            Spacer()
            Text(value)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
        }
    }
}
