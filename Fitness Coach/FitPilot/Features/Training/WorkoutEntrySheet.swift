//
//  WorkoutEntrySheet.swift
//  Fitness Coach
//
//  FitPilot AI — Add-workout form sheet.
//

import SwiftUI

struct WorkoutEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let errorMessage: String?
    let onSave: (WorkoutEntryFormState) async -> Void
    let onCancel: () -> Void

    @State private var formState = WorkoutEntryFormState()
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    TextField("Workout name", text: $formState.name)
                        .textInputAutocapitalization(.words)
                    TextField("Duration minutes", text: $formState.durationMinutesText)
                        .keyboardType(.numberPad)
                    TextField("Notes", text: $formState.notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    ForEach($formState.exerciseSets) { $set in
                        ExerciseSetInputRow(
                            set: $set,
                            canRemove: formState.exerciseSets.count > 1,
                            onRemove: { removeSet(id: set.id) }
                        )
                    }

                    Button {
                        addSet()
                    } label: {
                        Label("Add Set", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Exercise Sets")
                } footer: {
                    Text("Add at least one set. Weight and RPE are optional.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            SwiftUI.ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func addSet() {
        let nextNumber = formState.exerciseSets.count + 1
        formState.exerciseSets.append(
            ExerciseSetDraftRowState(setNumberText: "\(nextNumber)")
        )
    }

    private func removeSet(id: UUID) {
        guard formState.exerciseSets.count > 1 else { return }
        formState.exerciseSets.removeAll { $0.id == id }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            await onSave(formState)
            isSaving = false
        }
    }
}

#Preview {
    WorkoutEntrySheet(
        errorMessage: nil,
        onSave: { _ in },
        onCancel: {}
    )
}
