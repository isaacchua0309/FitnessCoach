//
//  WorkoutDetailView.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only workout detail.
//

import SwiftUI

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let workout: WorkoutDisplayItem
    let onDelete: (UUID) async -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(workout.name)
                            .font(.largeTitle.weight(.bold))
                        Text(workout.dateText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        WorkoutMetricCard(
                            title: "Duration",
                            value: workout.durationText ?? "--",
                            caption: nil,
                            systemImage: "timer"
                        )
                        WorkoutMetricCard(
                            title: "Calories",
                            value: workout.estimatedCaloriesText ?? "--",
                            caption: "estimated",
                            systemImage: "flame"
                        )
                        WorkoutMetricCard(
                            title: "Intensity",
                            value: workout.intensityText ?? "--",
                            caption: nil,
                            systemImage: "bolt"
                        )
                        WorkoutMetricCard(
                            title: "Volume",
                            value: TrainingFormatter.volume(workout.totalVolumeKg),
                            caption: "total",
                            systemImage: "scalemass"
                        )
                    }

                    if let recovery = workout.recoveryDemandText {
                        Label(recovery, systemImage: "heart")
                            .font(.subheadline.weight(.medium))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if let notes = workout.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            Text(notes)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ExerciseSetListView(sets: workout.exerciseSets)
                }
                .padding()
            }
            .navigationTitle("Workout Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        Task {
                            await onDelete(workout.id)
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete workout")
                }
            }
        }
    }
}

#Preview {
    WorkoutDetailView(workout: TrainingPreviewData.item, onDelete: { _ in })
}
