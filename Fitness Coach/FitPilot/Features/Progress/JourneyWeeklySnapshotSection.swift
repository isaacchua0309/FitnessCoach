//
//  JourneyWeeklySnapshotSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyWeeklySnapshotSection: View {
    let snapshot: JourneyWeeklySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            JourneySectionLabel(title: "This week")

            FitPilotPlanCard {
                VStack(spacing: 0) {
                    snapshotRow(
                        "Workout days",
                        snapshot.workoutDays == 0
                            ? FormaProductCopy.Journey.noWorkoutsYet
                            : "\(snapshot.workoutDays) days"
                    )
                    FitPilotPlanRowDivider()
                    snapshotRow(
                        "Protein target",
                        interpretation(
                            achieved: snapshot.proteinDaysAchieved,
                            total: snapshot.proteinDaysTotal,
                            strong: FormaProductCopy.Journey.proteinStrong,
                            weak: FormaProductCopy.Journey.proteinWeak
                        )
                    )
                    FitPilotPlanRowDivider()
                    snapshotRow(
                        "Water target",
                        interpretation(
                            achieved: snapshot.waterDaysAchieved,
                            total: snapshot.waterDaysTotal,
                            strong: FormaProductCopy.Journey.waterStrong,
                            weak: FormaProductCopy.Journey.waterWeak
                        )
                    )
                    if let deficit = snapshot.averageCalorieDeficit {
                        FitPilotPlanRowDivider()
                        snapshotRow(
                            "Avg calorie balance",
                            deficit > 0
                                ? "\(deficit) \(FormaProductCopy.Journey.kcalUnderTarget)"
                                : "\(abs(deficit)) \(FormaProductCopy.Journey.kcalAboveTarget)"
                        )
                    }
                    if let burned = snapshot.averageCaloriesBurned, burned > 0 {
                        FitPilotPlanRowDivider()
                        snapshotRow("Avg calories burned", "\(burned) kcal per workout")
                    }
                    if let duration = snapshot.averageTrainingDurationMinutes, duration > 0 {
                        FitPilotPlanRowDivider()
                        snapshotRow("Avg training duration", "\(duration) min")
                    }
                }
            }
        }
    }

    private func snapshotRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
            Text(value)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, FormaTokens.Spacing.xs + 2)
    }

    private func interpretation(achieved: Int, total: Int, strong: String, weak: String) -> String {
        guard total > 0 else { return FormaProductCopy.Journey.logMealsToTrack }
        let ratio = Double(achieved) / Double(total)
        if ratio >= 0.7 { return strong }
        if ratio >= 0.4 { return "\(achieved) of \(total) days on target" }
        return weak
    }
}
