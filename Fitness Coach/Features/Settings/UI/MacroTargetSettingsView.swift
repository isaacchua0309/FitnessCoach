//
//  MacroTargetSettingsView.swift
//  Fitness Coach
//
//  FitPilot AI — Macro and calorie target settings form section.
//

import SwiftUI

struct MacroTargetSettingsView: View {
    @Environment(\.planProjection) private var planProjection

    @Binding var calorieTargetText: String
    @Binding var proteinTargetText: String
    @Binding var carbTargetText: String
    @Binding var fatTargetText: String
    @Binding var expectedWeeklyWeightLossKgText: String
    @Binding var aggressiveness: CalorieAggressiveness

    var presentationStyle: PresentationStyle = .formSection
    let onRegenerate: () -> Void

    enum PresentationStyle {
        case formSection
        case embedded
    }

    var body: some View {
        switch presentationStyle {
        case .formSection:
            Section {
                fields
            } header: {
                FormaSettingsSectionHeader(title: "Macro Targets")
            } footer: {
                Text("Manual edits are saved as-is. Regenerate to recalculate from your profile and pace settings.")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planMutedText)
            }
        case .embedded:
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                Text("Macro Targets")
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                fields
            }
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                FormaLabeledNumberField(
                    title: FormaProductCopy.ProfileForm.calorieTarget,
                    placeholder: "2000",
                    text: $calorieTargetText,
                    unit: FormaProductCopy.FoodForm.kcalUnit,
                    keyboard: .numberPad
                )
                FormaLabeledNumberField(
                    title: FormaProductCopy.ProfileForm.proteinTarget,
                    placeholder: "140",
                    text: $proteinTargetText,
                    unit: FormaProductCopy.FoodForm.gramsUnit,
                    keyboard: .decimalPad
                )
                FormaLabeledNumberField(
                    title: FormaProductCopy.ProfileForm.carbTarget,
                    placeholder: "200",
                    text: $carbTargetText,
                    unit: FormaProductCopy.FoodForm.gramsUnit,
                    keyboard: .decimalPad
                )
                FormaLabeledNumberField(
                    title: FormaProductCopy.ProfileForm.fatTarget,
                    placeholder: "60",
                    text: $fatTargetText,
                    unit: FormaProductCopy.FoodForm.gramsUnit,
                    keyboard: .decimalPad
                )
                FormaLabeledNumberField(
                    title: FormaProductCopy.ProfileForm.weeklyLoss,
                    placeholder: "0.5",
                    text: $expectedWeeklyWeightLossKgText,
                    unit: FormaProductCopy.FoodForm.kgUnit,
                    keyboard: .decimalPad
                )

            Button {
                onRegenerate()
            } label: {
                Label("Regenerate Targets", systemImage: "arrow.triangle.2.circlepath")
            }
            .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
            .foregroundStyle(FormaPlanTokens.Color.planAccent)

            if presentationStyle == .formSection,
               let projection = planProjection,
               projection.hasEnergyTargets {
                PlanProjectionEnergyCard(projection: projection)
            }
        }
        .padding(.vertical, presentationStyle == .formSection ? FormaTokens.Spacing.xs : 0)
        .modifier(FormSectionChromeModifier(enabled: presentationStyle == .formSection))
    }
}

private struct FormSectionChromeModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.formaFormSection()
        } else {
            content
        }
    }
}

#Preview {
    Form {
        MacroTargetSettingsView(
            calorieTargetText: .constant("1850"),
            proteinTargetText: .constant("144"),
            carbTargetText: .constant("180"),
            fatTargetText: .constant("58"),
            expectedWeeklyWeightLossKgText: .constant("0.5"),
            aggressiveness: .constant(.moderate),
            onRegenerate: {}
        )
    }
    .formaGroupedList()
}
