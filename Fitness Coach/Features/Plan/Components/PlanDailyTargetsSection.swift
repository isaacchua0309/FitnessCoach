//
//  PlanDailyTargetsSection.swift
//  Fitness Coach
//
//  Forma — Daily prescription targets on the Plan dashboard.
//

import SwiftUI

struct PlanDailyTargetsSection: View {
    let state: DailyTargetsState
    var onGoToToday: (() -> Void)?

    @ScaledMetric(relativeTo: .title) private var calorieTargetSize: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
                    Text(state.caloriesLabel)
                        .font(.system(size: calorieTargetSize, weight: .bold, design: .rounded))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .minimumScaleFactor(0.75)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)

                    macroTargetsBlock

                    Text(state.prescriptionCopy)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, FormaTokens.Spacing.xs)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.accessibilitySummary)

            if let onGoToToday, let goToTodayTitle = state.goToTodayTitle {
                Button(action: onGoToToday) {
                    Text(goToTodayTitle)
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(FormaTokens.Theme.primary)
                }
                .buttonStyle(.plain)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .leading)
                .accessibilityLabel(goToTodayTitle)
                .accessibilityHint(FormaProductCopy.PlanDailyTargets.goToTodayAccessibilityHint)
            }
        }
    }

    private var macroTargetsBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            macroLine(state.proteinLabel)
            macroLine(state.carbsLabel)
            macroLine(state.fatLabel)
            macroLine(state.waterLabel)
            if let trainingTargetLabel = state.trainingTargetLabel {
                macroLine(trainingTargetLabel)
            }
        }
        .accessibilityHidden(true)
    }

    private func macroLine(_ text: String) -> some View {
        Text(text)
            .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
            .foregroundStyle(FormaTokens.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Previews

#Preview("Lose weight") {
    PlanDailyTargetsSection(
        state: PlanMissionControlFixtures.loseDashboard.dailyTargets,
        onGoToToday: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Large Dynamic Type") {
    PlanDailyTargetsSection(
        state: PlanMissionControlFixtures.loseDashboard.dailyTargets,
        onGoToToday: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
    .dynamicTypeSize(.accessibility3)
}

#Preview("Maintain") {
    PlanDailyTargetsSection(
        state: PlanMissionControlFixtures.maintainDashboard.dailyTargets,
        onGoToToday: nil
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
