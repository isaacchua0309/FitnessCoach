//
//  GoalProjectionCard.swift
//  Fitness Coach
//
//  FitPilot AI — Goal-weight projection card.
//

import SwiftUI

struct GoalProjectionCard: View {
    let projection: ProgressProjection?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Goal Projection", systemImage: "flag.checkered")
                .font(.headline)

            if let projection {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ProgressMetricCard(
                        title: "Current",
                        value: ProgressFormatter.kg(projection.currentWeightKg),
                        systemImage: "scalemass"
                    )
                    ProgressMetricCard(
                        title: "Goal",
                        value: ProgressFormatter.kg(projection.goalWeightKg),
                        systemImage: "target"
                    )
                    ProgressMetricCard(
                        title: "Remaining",
                        value: ProgressFormatter.kg(projection.remainingKg.map(abs)),
                        systemImage: "arrow.right"
                    )
                    ProgressMetricCard(
                        title: "Estimated time",
                        value: ProgressFormatter.weeks(projection.estimatedWeeksToGoal),
                        subtitle: ProgressFormatter.confidence(projection.confidence),
                        systemImage: "calendar"
                    )
                }

                Text("Projected goal date: \(ProgressFormatter.date(projection.projectedGoalDate))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Log more weigh-ins to project your goal date.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

#Preview {
    GoalProjectionCard(projection: ProgressPreviewData.state.goalProjection)
        .padding()
}
