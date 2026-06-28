//
//  TodayActivitySection.swift
//  Fitness Coach
//
//  Forma — Today's Activity: steps, workouts, and weekly training progress.
//

import SwiftUI

struct TodayActivitySection: View {
    let activity: ActivityTodayState
    let onConnectAppleHealth: () -> Void

    private var display: TodayActivitySectionPresentation {
        TodayActivitySectionFormatting.displayModel(for: activity)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.Activity.sectionTitle)

            FitPilotPlanCard {
                switch display {
                case .disconnected(let model):
                    disconnectedContent(model)
                case .connected(let model):
                    connectedContent(model)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func disconnectedContent(_ model: TodayActivityDisconnectedDisplayModel) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                if model.showsLockedIcon {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .accessibilityHidden(true)
                }

                Text(model.message)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(model.actionTitle) {
                onConnectAppleHealth()
            }
            .font(FormaTokens.Typography.caption.weight(.medium))
            .foregroundStyle(FormaTokens.Color.accent)
            .accessibilityLabel(model.actionTitle)
            .accessibilityHint(FormaProductCopy.Today.nextActionTrainingInsightsHint)
        }
        .padding(.vertical, FormaTokens.Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.accessibilitySummary)
    }

    @ViewBuilder
    private func connectedContent(_ model: TodayActivityConnectedDisplayModel) -> some View {
        if model.showsEmptyState, let emptyStateLine = model.emptyStateLine {
            Text(emptyStateLine)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .padding(.vertical, FormaTokens.Spacing.xs)
                .accessibilityLabel(model.accessibilitySummary)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if let stepsLine = model.stepsLine {
                    metricRow(
                        title: FormaProductCopy.Today.Activity.stepsLabel,
                        value: stepsLine,
                        detail: model.stepAssumptionLine
                    )

                    if model.weeklyProgressLine != nil || !model.workoutStatusLine.isEmpty {
                        FitPilotPlanRowDivider()
                    }
                } else if let stepAssumptionLine = model.stepAssumptionLine {
                    metricRow(
                        title: FormaProductCopy.Today.Activity.stepsLabel,
                        value: FormaProductCopy.Today.Activity.stepsUnavailable,
                        detail: stepAssumptionLine
                    )
                    FitPilotPlanRowDivider()
                }

                metricRow(
                    title: FormaProductCopy.Today.Activity.workoutLabel,
                    value: model.workoutStatusLine,
                    detail: nil
                )

                if let weeklyProgressLine = model.weeklyProgressLine {
                    FitPilotPlanRowDivider()

                    metricRow(
                        title: FormaProductCopy.Today.Activity.weeklyProgressLabel,
                        value: weeklyProgressLine,
                        detail: nil
                    )
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(model.accessibilitySummary)
        }
    }

    private func metricRow(title: String, value: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textTertiary)

            Text(value)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if let detail {
                Text(detail)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.vertical, TodayLayout.compactSpacing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue([value, detail].compactMap { $0 }.joined(separator: ". "))
    }
}

#Preview("Connected with data") {
    TodayActivitySection(
        activity: ActivityTodayState(
            legacyWorkoutSummary: TodayWorkoutSummary(
                workoutCaloriesBurned: 0,
                workoutCount: 0,
                hasWorkout: false
            ),
            trainingIntegration: .connected,
            trainingDataSource: .appleHealth,
            appleHealthWorkoutCount: 1,
            stepsToday: 8_432,
            weeklyWorkoutCount: 1,
            stepGoalAssumption: 7_500,
            trainingFrequencyPerWeek: 4,
            displayLine: FormaProductCopy.Today.workoutsToday(1),
            showsConnectCTA: false
        ),
        onConnectAppleHealth: {}
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}

#Preview("Disconnected") {
    TodayActivitySection(
        activity: ActivityTodayState(
            legacyWorkoutSummary: TodayWorkoutSummary(
                workoutCaloriesBurned: 0,
                workoutCount: 0,
                hasWorkout: false
            ),
            trainingIntegration: .notConnected,
            trainingDataSource: .appleHealth,
            appleHealthWorkoutCount: nil,
            stepsToday: nil,
            weeklyWorkoutCount: nil,
            stepGoalAssumption: 7_500,
            trainingFrequencyPerWeek: 4,
            displayLine: FormaProductCopy.Training.Integration.connectAppleHealth,
            showsConnectCTA: true
        ),
        onConnectAppleHealth: {}
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
