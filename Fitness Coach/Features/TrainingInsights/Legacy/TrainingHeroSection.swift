//
//  TrainingHeroSection.swift
//  Fitness Coach
//
//  FitPilot AI — Today's training status hero (read-only).
//

import SwiftUI

struct TrainingHeroSection: View {
    let hero: TrainingHeroState

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
            TrainingSectionLabel(title: "Today's training")

            FitPilotPlanCard {
                if hero.hasWorkoutToday, let workout = hero.primaryWorkout {
                    completedHero(workout)
                } else {
                    restDayHero
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var restDayHero: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs + 2) {
            Text("Rest day")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(FormaTokens.Color.textPrimary)

            Text(FormaProductCopy.Training.restDayGuidance)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textLegal)
                .fixedSize(horizontal: false, vertical: true)

            if let last = hero.lastWorkout {
                FitPilotPlanRowDivider()
                    .padding(.vertical, FormaTokens.Spacing.xs)

                Text("Last workout")
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textTertiary)

                Text(last.name)
                    .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)

                heroMetrics(for: last)
            }
        }
    }

    private func completedHero(_ workout: WorkoutDisplayItem) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs + 2) {
            Text("Workout completed")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(2)

            Text(workout.name)
                .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)

            heroMetrics(for: workout)

            Text("Completed \(workout.dateText)")
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
        }
    }

    private func heroMetrics(for workout: WorkoutDisplayItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let calories = workout.estimatedCaloriesText {
                metricLine("Calories", value: calories)
            }
            if let duration = workout.durationText {
                metricLine("Duration", value: duration)
            }
            metricLine("Exercises", value: "\(workout.exerciseCount)")
        }
        .padding(.top, 4)
    }

    private func metricLine(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
            Spacer()
            Text(value)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textPrimary)
        }
    }
}

#Preview("Completed") {
    TrainingHeroSection(hero: TrainingPreviewData.state.hero)
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}

#Preview("Rest") {
    TrainingHeroSection(hero: TrainingPreviewData.restDayHero)
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}
