//
//  ExerciseSetListView.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only exercise set display.
//

import SwiftUI

struct ExerciseSetListView: View {
    let sets: [ExerciseSet]

    private var groupedSets: [(String, [ExerciseSet])] {
        Dictionary(grouping: sets, by: \.exerciseName)
            .map { ($0.key, $0.value.sorted { $0.setNumber < $1.setNumber }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TrainingLayout.itemSpacing) {
            TrainingSectionLabel(title: "Exercises")

            if sets.isEmpty {
                Text("No exercise detail was parsed for this workout.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(groupedSets, id: \.0) { exerciseName, exerciseSets in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(exerciseName)
                                .font(.subheadline.weight(.semibold))

                            ForEach(exerciseSets) { set in
                                Text(TrainingFormatter.setLine(set))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ExerciseSetListView(sets: TrainingPreviewData.sets)
        .padding()
}
