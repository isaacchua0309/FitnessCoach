//
//  ManualFoodEntrySheet.swift
//  Fitness Coach
//
//  FitPilot AI — Add/edit manual food entry sheet.
//

import SwiftUI

struct ManualFoodEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: FoodEntryEditorMode
    let errorMessage: String?
    let onSave: (FoodEntryFormState) async -> Void
    let onDelete: (() async -> Void)?
    let onCancel: () -> Void

    @State private var formState: FoodEntryFormState
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var isShowingDeleteConfirmation = false

    init(
        mode: FoodEntryEditorMode,
        errorMessage: String?,
        onSave: @escaping (FoodEntryFormState) async -> Void,
        onDelete: (() async -> Void)?,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.errorMessage = errorMessage
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel

        switch mode {
        case .add:
            _formState = State(initialValue: FoodEntryFormState())
        case .edit(let entry):
            _formState = State(initialValue: FoodEntryFormState(foodEntry: entry))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                FoodEntryFormView(formState: $formState)

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .disabled(isSaving || isDeleting)
                }

                if case .edit = mode, onDelete != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Delete", role: .destructive) {
                            isShowingDeleteConfirmation = true
                        }
                        .disabled(isSaving || isDeleting)
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
                    .disabled(isSaving || isDeleting)
                }
            }
            .confirmationDialog(
                "Delete this food entry?",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteEntry()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the food from today's log.")
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            await onSave(formState)
            isSaving = false
        }
    }

    private func deleteEntry() {
        guard !isDeleting, let onDelete else { return }
        isDeleting = true
        Task {
            await onDelete()
            isDeleting = false
        }
    }
}

#Preview("Add") {
    ManualFoodEntrySheet(
        mode: .add,
        errorMessage: nil,
        onSave: { _ in },
        onDelete: nil,
        onCancel: {}
    )
}

#Preview("Edit") {
    ManualFoodEntrySheet(
        mode: .edit(TodayPreviewData.foodEntries[0]),
        errorMessage: nil,
        onSave: { _ in },
        onDelete: {},
        onCancel: {}
    )
}
