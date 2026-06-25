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
        VStack(alignment: .leading, spacing: 14) {
            Text("Exercise Sets")
                .font(.headline)

            if sets.isEmpty {
                Text("No sets logged.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groupedSets, id: \.0) { exerciseName, exerciseSets in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exerciseName)
                            .font(.subheadline.weight(.semibold))

                        ForEach(exerciseSets) { set in
                            HStack {
                                Text(TrainingFormatter.setLine(set))
                                    .font(.subheadline)
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
