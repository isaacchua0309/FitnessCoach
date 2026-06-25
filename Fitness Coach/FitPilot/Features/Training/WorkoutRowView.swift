//
//  WorkoutRowView.swift
//  Fitness Coach
//
//  FitPilot AI — Single workout row for Training lists.
//

import SwiftUI

struct WorkoutRowView: View {
    let workout: WorkoutDisplayItem
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(workout.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(workout.dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    if let durationText = workout.durationText {
                        label(durationText, systemImage: "timer")
                    }
                    if let caloriesText = workout.estimatedCaloriesText {
                        label(caloriesText, systemImage: "flame")
                    }
                    label("\(workout.setCount) sets", systemImage: "list.number")
                }

                HStack(spacing: 10) {
                    if let intensityText = workout.intensityText {
                        Text(intensityText)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.12), in: Capsule())
                    }
                    if let recoveryDemandText = workout.recoveryDemandText {
                        Text(recoveryDemandText)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.12), in: Capsule())
                    }
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete workout")
                }
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func label(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    WorkoutRowView(
        workout: TrainingPreviewData.item,
        onSelect: {},
        onDelete: {}
    )
    .padding()
}
