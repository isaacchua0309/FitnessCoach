//
//  AIFoodConfirmationSheet.swift
//  Fitness Coach
//
//  FitPilot AI — Sheet for confirming or rejecting an AI food estimate.
//

import SwiftUI

struct AIFoodConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let draft: AIFoodConfirmationDraft
    let errorMessage: String?
    let onConfirm: (FoodEntryFormState) async -> Void
    let onReject: () -> Void
    let onCancel: () -> Void

    @State private var formState: FoodEntryFormState
    @State private var isSaving = false

    init(
        draft: AIFoodConfirmationDraft,
        errorMessage: String?,
        onConfirm: @escaping (FoodEntryFormState) async -> Void,
        onReject: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.draft = draft
        self.errorMessage = errorMessage
        self.onConfirm = onConfirm
        self.onReject = onReject
        self.onCancel = onCancel

        if let foodDraft = draft.primaryFoodDraft {
            _formState = State(initialValue: FoodEntryFormState(foodDraft: foodDraft))
        } else {
            _formState = State(initialValue: FoodEntryFormState())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                AIFoodEstimateSummaryView(draft: draft)
                FoodEntryFormView(formState: $formState)

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Confirm Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button("Reject", role: .destructive) {
                        onReject()
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        confirm()
                    } label: {
                        if isSaving {
                            SwiftUI.ProgressView()
                        } else {
                            Text("Confirm Log")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func confirm() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            await onConfirm(formState)
            isSaving = false
        }
    }
}
