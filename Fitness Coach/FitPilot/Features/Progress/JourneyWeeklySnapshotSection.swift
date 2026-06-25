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

            VStack(spacing: 0) {
                snapshotRow(
                    "Workout days",
                    snapshot.workoutDays == 0
                        ? "None yet — log training in Coach"
                        : "\(snapshot.workoutDays) days"
                )
                divider
                snapshotRow(
                    "Protein target",
                    interpretation(
                        achieved: snapshot.proteinDaysAchieved,
                        total: snapshot.proteinDaysTotal,
                        strong: "Hit most days",
                        weak: "Room to improve"
                    )
                )
                divider
                snapshotRow(
                    "Water target",
                    interpretation(
                        achieved: snapshot.waterDaysAchieved,
                        total: snapshot.waterDaysTotal,
                        strong: "Hydration on track",
                        weak: "Hydration slipped"
                    )
                )
                if let deficit = snapshot.averageCalorieDeficit {
                    divider
                    snapshotRow(
                        "Avg calorie balance",
                        deficit > 0
                            ? "\(deficit) kcal under target"
                            : "\(abs(deficit)) kcal over target"
                    )
                }
                if let burned = snapshot.averageCaloriesBurned, burned > 0 {
                    divider
                    snapshotRow("Avg calories burned", "\(burned) kcal per workout")
                }
                if let duration = snapshot.averageTrainingDurationMinutes, duration > 0 {
                    divider
                    snapshotRow("Avg training duration", "\(duration) min")
                }
            }
        }
    }

    private var divider: some View {
        Divider().padding(.leading, 4)
    }

    private func snapshotRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }

    private func interpretation(achieved: Int, total: Int, strong: String, weak: String) -> String {
        guard total > 0 else { return "Log meals in Coach to track" }
        let ratio = Double(achieved) / Double(total)
        if ratio >= 0.7 { return strong }
        if ratio >= 0.4 { return "\(achieved) of \(total) days on target" }
        return weak
    }
}
