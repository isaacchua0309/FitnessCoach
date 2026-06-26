//
//  TrainingRecentWorkoutsSection.swift
//  Fitness Coach
//
//  FitPilot AI — Chronological recent workout list (read-only).
//

import SwiftUI

struct TrainingRecentWorkoutsSection: View {
    let workouts: [WorkoutDisplayItem]
    let onSelect: (WorkoutDisplayItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TrainingLayout.itemSpacing) {
            TrainingSectionLabel(title: "Recent workouts")

            FitPilotPlanCard {
                if workouts.isEmpty {
                    Text(FormaProductCopy.Training.noWorkoutsHint)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 0) {
                        ForEach(workouts) { workout in
                            Button {
                                onSelect(workout)
                            } label: {
                                recentRow(workout)
                            }
                            .buttonStyle(.plain)

                            if workout.id != workouts.last?.id {
                                FitPilotPlanRowDivider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func recentRow(_ workout: WorkoutDisplayItem) -> some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)

                Text(workout.dateText)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                if let duration = workout.durationText {
                    Text(duration)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                }
                if let calories = workout.estimatedCaloriesText {
                    Text(calories)
                        .font(FormaTokens.Typography.caption.weight(.medium))
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .padding(.top, 4)
        }
        .padding(.vertical, FormaTokens.Spacing.sm)
        .frame(minHeight: FitPilotScreenStyle.rowMinHeight, alignment: .center)
        .contentShape(Rectangle())
    }
}

#Preview {
    TrainingRecentWorkoutsSection(
        workouts: TrainingPreviewData.state.recentWorkouts,
        onSelect: { _ in }
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
