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
                            context: estimateContext,
                            sanityWarning: draft.sanityWarning
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
                        multiComponentNutritionSection
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
        FormaFormCard(title: FormaProductCopy.FoodForm.componentsSection) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                ForEach(Array(formState.componentStates.enumerated()), id: \.element.id) { index, component in
                    FoodComponentReadOnlyRow(
                        line: component.portionLine,
                        index: index + 1
                    )
                }
            }
        }
    }

    private var multiComponentNutritionSection: some View {
        FormaFormCard(title: FormaProductCopy.FoodForm.nutritionSection) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                Text("Total meal nutrition")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)

                FormaMacroInputGrid(
                    caloriesText: $formState.totalCaloriesText,
                    proteinText: $formState.totalProteinText,
                    carbsText: $formState.totalCarbsText,
                    fatText: $formState.totalFatText
                )
            }
        }
    }

    private var mealTypeBinding: Binding<MealType> {
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

private struct FoodComponentReadOnlyRow: View {
    let line: String
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Text("\(index).")
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .frame(width: 20, alignment: .trailing)

            Text(line)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Component \(index): \(line)")
    }
}
