//
//  WorkoutDetailView.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only workout detail from Coach-parsed data.
//

import SwiftUI

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let workout: WorkoutDisplayItem

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TrainingLayout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(workout.name)
                            .font(.title.weight(.bold))
                        Text(workout.dateText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: TrainingLayout.itemSpacing) {
                        TrainingSectionLabel(title: "Summary")

                        if let calories = workout.estimatedCaloriesText {
                            detailRow("Calories", value: calories)
                        }
                        if let duration = workout.durationText {
                            detailRow("Duration", value: duration)
                        }
                        detailRow("Exercises", value: "\(workout.exerciseCount)")
                        detailRow("Sets", value: "\(workout.setCount)")
                        if let volume = workout.totalVolumeKg, volume > 0 {
                            detailRow("Volume", value: TrainingFormatter.volume(volume))
                        }
                    }

                    if let notes = workout.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            TrainingSectionLabel(title: "Notes")
                            Text(notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ExerciseSetListView(sets: workout.exerciseSets)

                    Text(FormaProductCopy.Training.workoutCorrectionHint)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
                .padding(.horizontal, TrainingLayout.horizontalPadding)
                .padding(.vertical, 16)
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WorkoutDetailView(workout: TrainingPreviewData.item)
}
