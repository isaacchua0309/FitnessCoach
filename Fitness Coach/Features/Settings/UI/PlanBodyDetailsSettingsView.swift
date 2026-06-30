//
//  PlanBodyDetailsSettingsView.swift
//  Fitness Coach
//
//  Forma — Read-only body stats in Settings (not on Plan dashboard).
//

import SwiftUI

struct PlanBodyDetailsSettingsView: View {
    let formState: PlanFormState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
                FormaPlanCard {
                    VStack(spacing: 0) {
                        detailRow(
                            label: FormaProductCopy.ProfileForm.age,
                            value: "\(formState.ageText) years"
                        )
                        FormaPlanRowDivider()
                        detailRow(
                            label: FormaProductCopy.ProfileForm.height,
                            value: "\(formState.heightCmText) cm"
                        )
                        FormaPlanRowDivider()
                        detailRow(
                            label: FormaProductCopy.ProfileForm.sex,
                            value: PlanFormatter.sex(formState.sex)
                        )
                        FormaPlanRowDivider()
                        detailRow(
                            label: FormaProductCopy.ProfileForm.baselineWeight,
                            value: "\(formState.currentWeightKgText) kg"
                        )
                        FormaPlanRowDivider()
                        detailRow(
                            label: FormaProductCopy.ProfileForm.unitSystem,
                            value: PlanFormatter.unitSystem(formState.unitSystem)
                        )
                    }
                }

                Text(FormaProductCopy.PlanCalculation.bodyDetailsSettingsFootnote)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, FormaScreenStyle.horizontalPadding)
            .padding(.vertical, FormaTokens.Spacing.md)
        }
        .formaScreenBackground()
        .navigationTitle(FormaProductCopy.PlanCalculation.bodyDetailsSettingsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .formaScrollBottomInset()
    }

    private func detailRow(label: String, value: String) -> some View {
        FormaPlanDisplayRow(label: label, value: value)
    }
}

#Preview {
    NavigationStack {
        PlanBodyDetailsSettingsView(formState: PlanPreviewData.formState)
    }
    .formaThemePreview()
}
