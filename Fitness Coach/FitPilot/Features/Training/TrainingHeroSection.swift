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
        VStack(alignment: .leading, spacing: 14) {
            TrainingSectionLabel(title: "Today's training")

            if hero.hasWorkoutToday, let workout = hero.primaryWorkout {
                completedHero(workout)
            } else {
                restDayHero
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var restDayHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rest day")
                .font(.system(size: 40, weight: .bold, design: .rounded))

            Text("No workout logged today.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let last = hero.lastWorkout {
                Divider()
                    .padding(.vertical, 4)

                Text("Last workout")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)

                Text(last.name)
                    .font(.title3.weight(.semibold))

                heroMetrics(for: last)
            }
        }
    }

    private func completedHero(_ workout: WorkoutDisplayItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout completed")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(2)

            Text(workout.name)
                .font(.title3.weight(.semibold))

            heroMetrics(for: workout)

            Text("Completed \(workout.dateText)")
                .font(.caption)
                .foregroundStyle(.tertiary)
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
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }
}

#Preview("Completed") {
    TrainingHeroSection(hero: TrainingPreviewData.state.hero)
        .padding()
}

#Preview("Rest") {
    TrainingHeroSection(hero: TrainingPreviewData.restDayHero)
        .padding()
}
