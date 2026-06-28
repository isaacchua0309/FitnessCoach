//
//  PlanBodyDetailsSettingsView.swift
//  Fitness Coach
//
//  Forma — Read-only body stats in Settings (not on Plan dashboard).
//

import SwiftUI

struct PlanBodyDetailsSettingsView: View {
    let formState: ProfileFormState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
                FitPilotPlanCard {
                    VStack(spacing: 0) {
                        detailRow(
                            label: FormaProductCopy.ProfileForm.age,
                            value: "\(formState.ageText) years"
                        )
                        FitPilotPlanRowDivider()
                        detailRow(
                            label: FormaProductCopy.ProfileForm.height,
                            value: "\(formState.heightCmText) cm"
                        )
                        FitPilotPlanRowDivider()
                        detailRow(
                            label: FormaProductCopy.ProfileForm.sex,
                            value: ProfileFormatter.sex(formState.sex)
                        )
                        FitPilotPlanRowDivider()
                        detailRow(
                            label: FormaProductCopy.ProfileForm.baselineWeight,
                            value: "\(formState.currentWeightKgText) kg"
                        )
                        FitPilotPlanRowDivider()
                        detailRow(
                            label: FormaProductCopy.ProfileForm.unitSystem,
                            value: ProfileFormatter.unitSystem(formState.unitSystem)
                        )
                    }
                }

                Text(FormaProductCopy.PlanCalculation.bodyDetailsSettingsFootnote)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, FitPilotScreenStyle.horizontalPadding)
            .padding(.vertical, FormaTokens.Spacing.md)
        }
        .fitPilotDarkScreenBackground()
        .navigationTitle(FormaProductCopy.PlanCalculation.bodyDetailsSettingsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .fitPilotScrollBottomInset()
    }

    private func detailRow(label: String, value: String) -> some View {
        FitPilotPlanDisplayRow(label: label, value: value)
    }
}

#Preview {
    NavigationStack {
        PlanBodyDetailsSettingsView(formState: ProfilePreviewData.formState)
    }
    .preferredColorScheme(.dark)
}
