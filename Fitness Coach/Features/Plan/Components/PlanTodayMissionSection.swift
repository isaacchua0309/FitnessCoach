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

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            headerRow

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
                    macroTargetsBlock

                    Text(state.progressCopy)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            FormaSectionLabel(title: state.sectionTitle)

            Spacer(minLength: 8)

            if let onGoToToday {
                Button(state.goToTodayTitle, action: onGoToToday)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.accent)
                    .buttonStyle(.plain)
                    .frame(minHeight: FitPilotScreenStyle.rowMinHeight)
                    .accessibilityLabel(state.goToTodayTitle)
            }
        }
    }

    private var macroTargetsBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            macroLine(state.caloriesLabel)
            macroLine(state.proteinLabel)
            macroLine(state.carbsLabel)
            macroLine(state.fatLabel)
            macroLine(state.waterLabel)
        }
        .accessibilityHidden(true)
    }

    private func macroLine(_ text: String) -> some View {
        Text(text)
            .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
            .foregroundStyle(FormaTokens.Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
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
    .preferredColorScheme(.dark)
}

#Preview("Maintain") {
    PlanTodayMissionSection(
        state: PlanMissionControlFixtures.maintainDashboard.todayMission,
        onGoToToday: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
