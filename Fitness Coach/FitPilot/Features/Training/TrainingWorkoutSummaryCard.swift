//
//  TrainingWorkoutSummaryCard.swift
//  Fitness Coach
//
//  FitPilot AI — Summary card for the Training screen.
//

import SwiftUI

struct TrainingWorkoutSummaryCard: View {
    let summary: TrainingSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Training Summary")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                WorkoutMetricCard(
                    title: "Today",
                    value: "\(summary.workoutCountToday)",
                    caption: "workouts",
                    systemImage: "calendar"
                )
                WorkoutMetricCard(
                    title: "28 Days",
                    value: "\(summary.workoutCountInRecentRange)",
                    caption: "logged",
                    systemImage: "clock.arrow.circlepath"
                )
                WorkoutMetricCard(
                    title: "Burned",
                    value: "\(summary.estimatedCaloriesBurnedToday)",
                    caption: "kcal today",
                    systemImage: "flame"
                )
                WorkoutMetricCard(
                    title: "Volume",
                    value: TrainingFormatter.volume(summary.totalVolumeTodayKg),
                    caption: "today",
                    systemImage: "scalemass"
                )
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    TrainingWorkoutSummaryCard(summary: TrainingPreviewData.state.summary)
        .padding()
}
