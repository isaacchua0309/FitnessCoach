//
//  PlanTodayMissionSection.swift
//  Fitness Coach
//
//  Forma — Today's Mission card on the Plan dashboard.
//

import SwiftUI

struct PlanTodayMissionSection: View {
    let state: PlanTodayMissionState
    var onGoToToday: (() -> Void)?

    @ScaledMetric(relativeTo: .title) private var calorieTargetSize: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            PlanSectionHeader(
                title: state.sectionTitle,
                actionTitle: onGoToToday == nil ? nil : state.goToTodayTitle,
                actionAccessibilityHint: FormaProductCopy.PlanMissionControl.goToTodayAccessibilityHint,
                action: onGoToToday
            )

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
                    Text(state.caloriesLabel)
                        .font(.system(size: calorieTargetSize, weight: .bold, design: .rounded))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .minimumScaleFactor(0.75)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)

                    secondaryMacroTargetsBlock

                    Text(state.progressCopy)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(cardAccessibilitySummary)
        }
    }

    private var secondaryMacroTargetsBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            secondaryMacroLine(state.proteinLabel)
            secondaryMacroLine(state.carbsLabel)
            secondaryMacroLine(state.fatLabel)
            secondaryMacroLine(state.waterLabel)
        }
        .accessibilityHidden(true)
    }

    private func secondaryMacroLine(_ text: String) -> some View {
        Text(text)
            .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
            .foregroundStyle(FormaTokens.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var cardAccessibilitySummary: String {
        [
            state.sectionTitle,
            state.caloriesLabel,
            state.proteinLabel,
            state.carbsLabel,
            state.fatLabel,
            state.waterLabel,
            state.progressCopy
        ].joined(separator: ". ")
    }
}

// MARK: - Previews

#Preview("Lose weight") {
    PlanTodayMissionSection(
        state: PlanMissionControlFixtures.loseDashboard.todayMission,
        onGoToToday: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Large Dynamic Type") {
    PlanTodayMissionSection(
        state: PlanMissionControlFixtures.loseDashboard.todayMission,
        onGoToToday: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
    .dynamicTypeSize(.accessibility3)
}

#Preview("Maintain") {
    PlanTodayMissionSection(
        state: PlanMissionControlFixtures.maintainDashboard.todayMission,
        onGoToToday: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
