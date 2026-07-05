//
//  TodayActivitySection.swift
//  Fitness Coach
//
//  Forma — Compact Today's Activity: steps and workout status.
//

import SwiftUI

struct TodayActivitySection: View {
    let activity: ActivityTodayState
    let onConnectAppleHealth: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    private var display: TodayActivityCompactDisplayModel {
        TodayActivitySectionFormatting.displayModel(for: activity)
    }

    var body: some View {
        let _ = themeManager.themeRevision
        return VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.Activity.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                    Text(display.stepsLine)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(theme.primaryText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(display.workoutLine)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    if let healthNote = display.healthNote {
                        healthConnectionNote(
                            note: healthNote,
                            actionTitle: display.healthActionTitle
                        )
                    }
                }
                .padding(.vertical, FormaTokens.Spacing.sm)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(display.accessibilitySummary)
            }
        }
        .accessibilityElement(children: .contain)
        .todayLiveTheme()
    }

    @ViewBuilder
    private func healthConnectionNote(note: String, actionTitle: String?) -> some View {
        if let actionTitle {
            Button(actionTitle) {
                onConnectAppleHealth()
            }
            .font(FormaTokens.Typography.caption)
            .foregroundStyle(theme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, FormaTokens.Spacing.xs)
            .accessibilityLabel(actionTitle)
            .accessibilityHint(note)
        } else {
            Text(note)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(theme.tertiaryText)
                .padding(.top, FormaTokens.Spacing.xs)
        }
    }
}

#Preview("Connected with data") {
    TodayActivitySection(
        activity: ActivityTodayState(
            phase: .hasData,
            sectionTitle: FormaProductCopy.Today.Activity.sectionTitle,
            legacyWorkoutSummary: TodayWorkoutSummary(
                workoutCaloriesBurned: 0,
                workoutCount: 0,
                hasWorkout: false
            ),
            trainingIntegration: .connected,
            trainingDataSource: .appleHealth,
            appleHealthWorkoutCount: 0,
            stepsToday: 1_827,
            stepGoalAssumption: 7_500,
            showsConnectCTA: false,
            date: Date(),
            trainingFrequencyPerWeek: 3
        ),
        onConnectAppleHealth: {}
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Disconnected") {
    TodayActivitySection(
        activity: ActivityTodayState(
            phase: .disconnected,
            sectionTitle: FormaProductCopy.Today.Activity.sectionTitle,
            legacyWorkoutSummary: TodayWorkoutSummary(
                workoutCaloriesBurned: 0,
                workoutCount: 0,
                hasWorkout: false
            ),
            trainingIntegration: .notConnected,
            trainingDataSource: .appleHealth,
            appleHealthWorkoutCount: nil,
            stepsToday: nil,
            stepGoalAssumption: 7_500,
            showsConnectCTA: true,
            date: Date(),
            trainingFrequencyPerWeek: 0
        ),
        onConnectAppleHealth: {}
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
