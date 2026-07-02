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
    let onDone: (FoodLogEditFormState) -> Void
    let onCancel: () -> Void

    @State private var formState: FoodLogEditFormState

    init(
        draft: AIFoodConfirmationDraft,
        errorMessage: String?,
        onDone: @escaping (FoodLogEditFormState) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.draft = draft
        self.errorMessage = errorMessage
        self.onDone = onDone
        self.onCancel = onCancel
        _formState = State(initialValue: FoodLogEditFormState(mealDraft: draft.primaryMealDraft))
    }

    private var estimateContext: String? {
        let assistant = draft.assistantMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = draft.primaryMealDraft.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let assistant, !assistant.isEmpty { return assistant }
        if let notes, !notes.isEmpty { return notes }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sectionSpacing) {
                    FormaFormCard(title: FormaProductCopy.FoodForm.estimateSection) {
                        FormaEstimateContextBanner(
                            confidence: draft.confidence,
                            context: estimateContext
                        )
                    }

                    FormaFormCard(title: FormaProductCopy.FoodForm.whatYouAteSection) {
                        FormaLabeledField(
                            title: FormaProductCopy.FoodForm.foodName,
                            placeholder: FormaProductCopy.FoodForm.foodNamePlaceholder,
                            text: $formState.displayName,
                            capitalization: .words
                        )
                        mealTypePicker
                    }

                    if formState.isMultiComponent {
                        componentsSection
                        totalsSection
                    } else if !formState.componentStates.isEmpty {
                        singleComponentSection(index: 0)
                    }

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
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
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

    private var componentsSection: some View {
        FormaFormCard(title: "Ingredients") {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                ForEach($formState.componentStates) { $component in
                    FoodComponentEditCard(component: $component)
                }
            }
        }
    }

    private var totalsSection: some View {
        FormaFormCard(title: FormaProductCopy.FoodForm.nutritionSection) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                Text("\(formState.totalCalories) kcal total")
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                Text("Totals are calculated from the ingredients above.")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
            }
        }
    }

    private func singleComponentSection(index: Int) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sectionSpacing) {
            FormaFormCard(title: FormaProductCopy.FoodForm.portionSection) {
                HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                    FormaLabeledNumberField(
                        title: FormaProductCopy.FoodForm.amount,
                        placeholder: FormaProductCopy.FoodForm.amountPlaceholder,
                        text: $formState.componentStates[index].quantityText,
                        keyboard: .decimalPad
                    )
                    FormaLabeledField(
                        title: FormaProductCopy.FoodForm.unit,
                        placeholder: FormaProductCopy.FoodForm.unitPlaceholder,
                        text: $formState.componentStates[index].unit,
                        capitalization: .never
                    )
                }
            }

            FormaFormCard(title: FormaProductCopy.FoodForm.nutritionSection) {
                FormaMacroInputGrid(
                    caloriesText: $formState.componentStates[index].caloriesText,
                    proteinText: $formState.componentStates[index].proteinText,
                    carbsText: $formState.componentStates[index].carbsText,
                    fatText: $formState.componentStates[index].fatText
                )
            }
        }
    }

    private var mealTypeBinding: Binding<MealType> {
        Binding(
            get: { formState.mealType ?? .unknown },
            set: { formState.mealType = $0 }
        )
    }

    private var mealTypePicker: some View {
        FormaPickerRow(title: FormaProductCopy.FoodForm.mealType, selection: mealTypeBinding) {
            ForEach(MealType.allCases, id: \.self) { type in
                Text(FoodEntryFormFormatter.mealTypeLabel(type)).tag(type)
            }
        }
    }
}

private struct FoodComponentEditCard: View {
    @Binding var component: FoodComponentFormState

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            FormaLabeledField(
                title: FormaProductCopy.FoodForm.foodName,
                placeholder: FormaProductCopy.FoodForm.foodNamePlaceholder,
                text: $component.name,
                capitalization: .words
            )

            HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                FormaLabeledNumberField(
                    title: FormaProductCopy.FoodForm.amount,
                    placeholder: FormaProductCopy.FoodForm.amountPlaceholder,
                    text: $component.quantityText,
                    keyboard: .decimalPad
                )
                FormaLabeledField(
                    title: FormaProductCopy.FoodForm.unit,
                    placeholder: FormaProductCopy.FoodForm.unitPlaceholder,
                    text: $component.unit,
                    capitalization: .never
                )
            }

            FormaLabeledField(
                title: "Preparation",
                placeholder: "cooked, raw, etc.",
                text: $component.preparationState,
                capitalization: .never
            )

            FormaMacroInputGrid(
                caloriesText: $component.caloriesText,
                proteinText: $component.proteinText,
                carbsText: $component.carbsText,
                fatText: $component.fatText
            )

            if !component.sourceText.isEmpty {
                Text(component.sourceText)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
            }
        }
        .padding(FormaTokens.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(FormaTokens.Color.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .stroke(FormaTokens.Color.border, lineWidth: 1)
        }
    }
}
