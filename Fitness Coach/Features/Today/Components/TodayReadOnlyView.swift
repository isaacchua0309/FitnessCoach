//
//  TodayReadOnlyView.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only Today dashboard. All updates route to Coach.
//

import SwiftUI

struct TodayReadOnlyView: View {
    let state: TodayDashboardState
    let trainingIntegration: TrainingIntegrationState
    let trainingDataSource: TrainingDataSource
    let appleHealthWorkoutCount: Int?
    let onOpenCoach: (String?) -> Void
    let onOpenTrainingInsights: () -> Void

    init(
        state: TodayDashboardState,
        trainingIntegration: TrainingIntegrationState = .connected,
        trainingDataSource: TrainingDataSource = .appleHealth,
        appleHealthWorkoutCount: Int? = nil,
        onOpenCoach: @escaping (String?) -> Void,
        onOpenTrainingInsights: @escaping () -> Void = {}
    ) {
        self.state = state
        self.trainingIntegration = trainingIntegration
        self.trainingDataSource = trainingDataSource
        self.appleHealthWorkoutCount = appleHealthWorkoutCount
        self.onOpenCoach = onOpenCoach
        self.onOpenTrainingInsights = onOpenTrainingInsights
    }

    private var goals: [TodayGoalItem] {
        TodayGoalsBuilder.goals(
            from: state,
            trainingIntegration: trainingIntegration,
            trainingDataSource: trainingDataSource,
            appleHealthWorkoutCount: appleHealthWorkoutCount
        )
    }

    private var showsGenericCoachCTA: Bool {
        TodayCoachCTAPolicy.showsGenericCoachCTA(
            foodEntries: state.foodEntries,
            goals: goals
        )
    }

    private var focusMessage: String {
        TodayFocusBuilder.focus(
            from: state,
            trainingIntegration: trainingIntegration,
            trainingDataSource: trainingDataSource
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.zoneSpacing) {
            statusZone

            TodayGoalChecklist(
                goals: goals,
                onGoalTap: handleGoalTap
            )

            loggedItemsZone

            if showsGenericCoachCTA {
                AskCoachCTA {
                    onOpenCoach(nil)
                }
            }
        }
    }

    // MARK: - Zones

    /// Status: calorie headline + one-line focus.
    private var statusZone: some View {
        VStack(alignment: .leading, spacing: TodayLayout.statusZoneSpacing) {
            TodayCaloriesHero(calories: state.calorieSummary)
            TodayFocusSection(message: focusMessage)
        }
    }

    /// Logged items: measurement targets + meal timeline.
    private var loggedItemsZone: some View {
        VStack(alignment: .leading, spacing: TodayLayout.loggedZoneSpacing) {
            TodayReadOnlyProgressSection(
                macros: state.macroSummary,
                water: state.waterSummary
            )

            TodayMealsPreview(
                entries: state.foodEntries,
                previewLimit: 3,
                onLogMeal: {
                    onOpenCoach(TodayCoachPrompt.logMeal)
                }
            )
        }
    }

    private func handleGoalTap(_ goal: TodayGoalItem) {
        switch goal.tapAction {
        case .coach(let prefill):
            onOpenCoach(prefill)
        case .openTrainingInsights:
            onOpenTrainingInsights()
        case nil:
            break
        }
    }
}

#Preview {
    ScrollView {
        TodayReadOnlyView(state: TodayPreviewData.state) { _ in }
            .padding(.horizontal, TodayLayout.horizontalPadding)
            .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}

#Preview("Small phone") {
    ScrollView {
        TodayReadOnlyView(state: TodayPreviewData.state) { _ in }
            .padding(.horizontal, TodayLayout.horizontalPadding)
            .frame(width: 320)
    }
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
