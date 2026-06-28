//
//  TodayLogMealSheet.swift
//  Fitness Coach
//
//  Forma — Native Today sheet for logging a meal via FitnessActionCenter.
//

import SwiftUI

struct TodayLogMealSheet: View {
    @Environment(\.dismiss) private var dismiss

    let initialMealType: MealType?
    let errorMessage: String?
    let onSave: (FoodEntryFormState) -> Void

    @State private var formState: FoodEntryFormState

    init(
        initialMealType: MealType?,
        errorMessage: String?,
        onSave: @escaping (FoodEntryFormState) -> Void
    ) {
        self.initialMealType = initialMealType
        self.errorMessage = errorMessage
        self.onSave = onSave
        var state = FoodEntryFormState()
        state.mealType = initialMealType
        _formState = State(initialValue: state)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sectionSpacing) {
                    FoodEntryFormView(formState: $formState, mode: .manualEntry)

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
                .padding(.horizontal, FitPilotScreenStyle.horizontalPadding)
                .padding(.top, FormaTokens.Spacing.md)
                .padding(.bottom, FormaTokens.Spacing.lg)
            }
            .fitPilotFormScreen()
            .navigationTitle(FormaProductCopy.Today.NextAction.sheetLogMealTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(FormaProductCopy.Common.cancel) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(FormaProductCopy.Today.NextAction.sheetSave) {
                        onSave(formState)
                    }
                }
            }
        }
    }
}
