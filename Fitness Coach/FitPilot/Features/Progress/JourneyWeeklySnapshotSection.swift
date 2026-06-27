//
//  JourneyWeeklySnapshotSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyWeeklySnapshotSection: View {
    let snapshot: JourneyWeeklySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            JourneySectionLabel(title: FormaProductCopy.Journey.sectionThisWeek)

            FitPilotPlanCard {
                VStack(spacing: 0) {
                    if snapshot.training.showsWorkoutRow {
                        compactRow("Workout days", workoutStatus)
                        FitPilotPlanRowDivider()
                    }
                    compactRow("Protein", proteinStatus)
                    FitPilotPlanRowDivider()
                    compactRow("Water", waterStatus)
                    FitPilotPlanRowDivider()
                    compactRow("Calories", calorieStatus)
                }
            }
        }
    }

    private var workoutStatus: String {
        switch snapshot.training {
        case .hidden:
            return FormaProductCopy.Journey.statusNoData
        case .locked:
            return FormaProductCopy.Journey.trainingInsightsLocked
        case .connectedEmpty:
            return FormaProductCopy.Journey.noAppleHealthWorkoutsThisWeek
        case .connected(let days, _, _):
            return ProgressFormatter.dayCount(days)
        }
    }

    private var proteinStatus: String {
        targetStatus(achieved: snapshot.proteinDaysAchieved, total: snapshot.proteinDaysTotal)
    }

    private var waterStatus: String {
        targetStatus(achieved: snapshot.waterDaysAchieved, total: snapshot.waterDaysTotal)
    }

    private var calorieStatus: String {
        guard let deficit = snapshot.averageCalorieDeficit else {
            return FormaProductCopy.Journey.statusNoData
        }
        if deficit > 50 { return FormaProductCopy.Journey.statusUnderTarget }
        if deficit < -50 { return FormaProductCopy.Journey.statusAboveTarget }
        return FormaProductCopy.Journey.statusOnTrack
    }

    private func targetStatus(achieved: Int, total: Int) -> String {
        guard total > 0 else { return FormaProductCopy.Journey.statusNoData }
        let ratio = Double(achieved) / Double(total)
        if ratio >= 0.7 { return FormaProductCopy.Journey.statusOnTrack }
        if ratio >= 0.4 { return FormaProductCopy.Journey.statusNeedsAttention }
        return FormaProductCopy.Journey.statusBehind
    }

    private func compactRow(_ label: String, _ status: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
            Spacer(minLength: FormaTokens.Spacing.xs)
            Text(status)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: FitPilotScreenStyle.rowMinHeight, alignment: .leading)
    }
}
