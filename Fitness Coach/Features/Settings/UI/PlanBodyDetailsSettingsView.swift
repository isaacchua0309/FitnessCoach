//
//  PlanBodyDetailsSettingsView.swift
//  Fitness Coach
//
//  Forma — Read-only body stats in Settings with Adjust Plan routing.
//

import SwiftUI

struct PlanBodyDetailsSettingsView: View {
    let presentation: BodyDetailsSettingsPresentation
    let onUpdateInPlan: () -> Void

    var body: some View {
        formaSettingsDetailScreen {
            VStack(alignment: .leading, spacing: SettingsChromeAccessibility.detailSectionSpacing) {
                Text(presentation.introCopy)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                profileDetailsSection
                updateInPlanSection
            }
        }
        .navigationTitle(presentation.screenTitle)
    }

    // MARK: - Sections

    private var profileDetailsSection: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            sectionHeader(presentation.profileDetailsSectionTitle)

            FormaPlanCard(compact: true) {
                VStack(spacing: 0) {
                    ForEach(Array(presentation.detailRows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 {
                            FormaPlanRowDivider()
                        }

                        FormaPlanDisplayRow(label: row.label, value: row.value)
                    }
                }
            }
        }
    }

    private var updateInPlanSection: some View {
        Button(action: onUpdateInPlan) {
            Text(presentation.updateInPlanCTA)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: SettingsChromeAccessibility.minimumActionButtonHeight)
        }
        .buttonStyle(.borderedProminent)
        .tint(FormaTokens.Theme.primary)
        .accessibilityLabel(presentation.updateInPlanCTA)
        .accessibilityHint(presentation.updateInPlanAccessibilityHint)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(FormaTokens.Color.textTertiary)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Previews

#Preview("Complete profile") {
    NavigationStack {
        PlanBodyDetailsSettingsView(
            presentation: BodyDetailsSettingsPresentationBuilder.build(
                input: BodyDetailsSettingsPresentationInput(formState: PlanPreviewData.formState)
            ),
            onUpdateInPlan: {}
        )
    }
    .formaThemePreview()
}

#Preview("Imperial display") {
    NavigationStack {
        PlanBodyDetailsSettingsView(
            presentation: BodyDetailsSettingsPresentationBuilder.build(
                input: BodyDetailsSettingsPresentationInput(
                    formState: {
                        var state = PlanPreviewData.formState
                        state.unitSystem = .imperial
                        return state
                    }(),
                    startingWeightKg: 90,
                    currentWeightKg: 88.2
                )
            ),
            onUpdateInPlan: {}
        )
    }
    .formaThemePreview()
}

#Preview("Missing values") {
    NavigationStack {
        PlanBodyDetailsSettingsView(
            presentation: BodyDetailsSettingsPresentationBuilder.build(
                input: BodyDetailsSettingsPresentationInput(
                    formState: {
                        var state = PlanFormState.defaultDraftValues()
                        state.ageText = ""
                        state.heightCmText = ""
                        state.currentWeightKgText = ""
                        state.sex = .preferNotToSay
                        return state
                    }()
                )
            ),
            onUpdateInPlan: {}
        )
    }
    .formaThemePreview()
}
