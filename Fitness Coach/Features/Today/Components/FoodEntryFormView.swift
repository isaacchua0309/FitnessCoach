//
//  FoodEntryFormView.swift
//  Fitness Coach
//
//  FitPilot AI — Form fields for food entry and Coach edit.
//

import SwiftUI

struct FoodEntryFormView: View {
    @Binding var formState: FoodEntryFormState
    var mode: FoodEntryFormMode = .manualEntry

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sectionSpacing) {
            if mode.showsEstimateBanner, case .coachEdit(let context, let confidence) = mode {
                FormaFormCard(title: FormaProductCopy.FoodForm.estimateSection) {
                    FormaEstimateContextBanner(confidence: confidence, context: context)
                }
            }

            FormaFormCard(title: FormaProductCopy.FoodForm.whatYouAteSection) {
                FormaLabeledField(
                    title: FormaProductCopy.FoodForm.foodName,
                    placeholder: FormaProductCopy.FoodForm.foodNamePlaceholder,
                    text: $formState.name,
                    capitalization: .words
                )

                mealTypePicker
            }

            if mode.showsPortionFields {
                FormaFormCard(title: FormaProductCopy.FoodForm.portionSection) {
                    HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                        FormaLabeledNumberField(
                            title: FormaProductCopy.FoodForm.amount,
                            placeholder: FormaProductCopy.FoodForm.amountPlaceholder,
                            text: $formState.quantityText,
                            keyboard: .decimalPad
                        )
                        FormaLabeledField(
                            title: FormaProductCopy.FoodForm.unit,
                            placeholder: FormaProductCopy.FoodForm.unitPlaceholder,
                            text: $formState.unit,
                            capitalization: .never
                        )
                    }
                }
            }

            FormaFormCard(title: FormaProductCopy.FoodForm.nutritionSection) {
                FormaMacroInputGrid(
                    caloriesText: $formState.caloriesText,
                    proteinText: $formState.proteinText,
                    carbsText: $formState.carbsText,
                    fatText: $formState.fatText
                )
            }

            if mode.showsAdvancedNutrients {
                FormaFormCard(title: FormaProductCopy.FoodForm.advancedSection) {
                    FormaLabeledNumberField(
                        title: FormaProductCopy.FoodForm.fiber,
                        placeholder: "0",
                        text: $formState.fiberText,
                        unit: FormaProductCopy.FoodForm.gramsUnit,
                        keyboard: .decimalPad
                    )
                    FormaLabeledNumberField(
                        title: FormaProductCopy.FoodForm.sodium,
                        placeholder: "0",
                        text: $formState.sodiumText,
                        unit: FormaProductCopy.FoodForm.mgUnit,
                        keyboard: .numberPad
                    )
                }
            }

            if mode.showsUserNotes {
                FormaFormCard {
                    FormaLabeledField(
                        title: FormaProductCopy.FoodForm.notes,
                        placeholder: FormaProductCopy.FoodForm.notesPlaceholder,
                        text: $formState.notes,
                        axis: .vertical,
                        lineLimit: 2...4
                    )
                }
            }
        }
    }

    private var mealTypePicker: some View {
        FormaPickerRow(title: FormaProductCopy.FoodForm.mealType, selection: mealTypeBinding) {
            ForEach(MealType.allCases, id: \.self) { type in
                Text(FoodEntryFormFormatter.mealTypeLabel(type)).tag(type)
            }
        }
    }

    private var mealTypeBinding: Binding<MealType> {
        Binding(
            get: { formState.mealType ?? .unknown },
            set: { formState.mealType = $0 }
        )
    }
}

#Preview("Coach edit — filled") {
    ScrollView {
        FoodEntryFormView(
            formState: .constant(
                FoodEntryFormState(
                    foodDraft: FoodDraft(
                        mealType: nil,
                        name: "KFC chicken",
                        quantity: 3,
                        unit: "pieces",
                        calories: 810,
                        protein: 48,
                        carbs: 48,
                        fat: 24,
                        fiber: nil,
                        sodium: nil,
                        source: .aiTextEstimate,
                        confidence: .medium,
                        imageUrl: nil,
                        notes: "AI note should not appear in form"
                    ),
                    excludeAINotes: true
                )
            ),
            mode: .coachEdit(
                estimateContext: "Estimated for 3 pieces of fried chicken; exact calories vary by cut and breading.",
                confidence: .medium
            )
        )
        .padding(.horizontal, FitPilotScreenStyle.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .fitPilotFormScreen()
}
