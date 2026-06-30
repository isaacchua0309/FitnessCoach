//
//  AIFoodConfirmationSheet.swift
//  Fitness Coach
//
//  FitPilot AI — Edit sheet for adjusting a pending food estimate before logging.
//

import SwiftUI

struct AIFoodConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let draft: AIFoodConfirmationDraft
    let errorMessage: String?
    let onDone: (FoodEntryFormState) -> Void
    let onCancel: () -> Void

    @State private var formState: FoodEntryFormState

    init(
        draft: AIFoodConfirmationDraft,
        errorMessage: String?,
        onDone: @escaping (FoodEntryFormState) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.draft = draft
        self.errorMessage = errorMessage
        self.onDone = onDone
        self.onCancel = onCancel

        if let foodDraft = draft.primaryFoodDraft {
            _formState = State(
                initialValue: FoodEntryFormState(foodDraft: foodDraft, excludeAINotes: true)
            )
        } else {
            _formState = State(initialValue: FoodEntryFormState())
        }
    }

    private var estimateContext: String? {
        let assistant = draft.assistantMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = draft.primaryFoodDraft?.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let assistant, !assistant.isEmpty { return assistant }
        if let notes, !notes.isEmpty { return notes }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sectionSpacing) {
                    FoodEntryFormView(
                        formState: $formState,
                        mode: .coachEdit(
                            estimateContext: estimateContext,
                            confidence: draft.confidence
                        )
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(FormaTokens.Spacing.md)
                            .background {
                                RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                                    .fill(FormaTokens.Color.destructive.opacity(0.12))
                            }
                    }
                }
                .padding(.horizontal, FormaScreenStyle.horizontalPadding)
                .padding(.top, FormaTokens.Spacing.md)
                .padding(.bottom, FormaTokens.Spacing.lg)
            }
            .formaFormScreen()
            .navigationTitle("Edit food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(formState)
                        dismiss()
                    }
                }
            }
        }
    }
}
