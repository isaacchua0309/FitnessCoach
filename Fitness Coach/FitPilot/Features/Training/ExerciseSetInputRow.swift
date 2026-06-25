//
//  ExerciseSetInputRow.swift
//  Fitness Coach
//
//  FitPilot AI — Form row for a pending exercise set.
//

import SwiftUI

struct ExerciseSetInputRow: View {
    @Binding var set: ExerciseSetDraftRowState
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Set")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if canRemove {
                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "minus.circle")
                    }
                    .accessibilityLabel("Remove set")
                }
            }

            TextField("Exercise name", text: $set.exerciseName)
                .textInputAutocapitalization(.words)

            HStack {
                TextField("Set #", text: $set.setNumberText)
                    .keyboardType(.numberPad)
                TextField("Reps", text: $set.repsText)
                    .keyboardType(.numberPad)
            }

            HStack {
                TextField("Weight kg", text: $set.weightKgText)
                    .keyboardType(.decimalPad)
                TextField("RPE 1-10", text: $set.rpeText)
                    .keyboardType(.decimalPad)
            }
        }
    }
}

#Preview {
    ExerciseSetInputRowPreview()
}

private struct ExerciseSetInputRowPreview: View {
    @State private var set = ExerciseSetDraftRowState(
        exerciseName: "Squat",
        setNumberText: "1",
        repsText: "5",
        weightKgText: "120",
        rpeText: "8"
    )

    var body: some View {
        Form {
            ExerciseSetInputRow(
                set: $set,
                canRemove: true,
                onRemove: {}
            )
        }
    }
}
