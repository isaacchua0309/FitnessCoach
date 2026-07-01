//
//  TodayEditFoodEntrySheet.swift
//  Fitness Coach
//
//  Forma — Edit an existing food entry from Today.
//

import SwiftUI

struct TodayEditFoodEntrySheet: View {
    @Environment(\.dismiss) private var dismiss

    let entry: FoodEntry
    let errorMessage: String?
    let onSave: (FoodEntryFormState) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    @State private var formState: FoodEntryFormState

    init(
        entry: FoodEntry,
        errorMessage: String?,
        onSave: @escaping (FoodEntryFormState) -> Void,
        onDelete: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.entry = entry
        self.errorMessage = errorMessage
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _formState = State(initialValue: FoodEntryFormState(foodEntry: entry))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sectionSpacing) {
                    FoodEntryProvenanceBanner(source: entry.source, confidence: entry.confidence)

                    FoodEntryFormView(formState: $formState, mode: .todayManualEntry)

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

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Text(FormaProductCopy.Today.Meals.deleteAction)
                            .font(FormaTokens.Typography.bodyMedium)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, FormaTokens.Spacing.sm)
                }
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.top, FormaTokens.Spacing.md)
                .padding(.bottom, FormaTokens.Spacing.lg)
            }
            .formaFormScreen()
            .navigationTitle(FormaProductCopy.Today.Meals.editSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(FormaProductCopy.Common.cancel) {
                        onCancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(FormaProductCopy.Today.Meals.saveEditAction) {
                        onSave(formState)
                    }
                }
            }
        }
    }
}
