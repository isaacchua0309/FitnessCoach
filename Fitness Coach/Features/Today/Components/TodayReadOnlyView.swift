//
//  TodayReadOnlyView.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only Today dashboard. Mutations route through TodayActionCoordinator.
//

import SwiftUI

struct TodayReadOnlyView: View {
    let state: TodayDashboardState
    let actionCoordinator: TodayActionCoordinator
    let onOpenCoach: (String?) -> Void
    let onOpenJourney: () -> Void
    let onOpenPlan: () -> Void

    init(
        state: TodayDashboardState,
        actionCoordinator: TodayActionCoordinator,
        trainingIntegration: TrainingIntegrationState = .connected,
        trainingDataSource: TrainingDataSource = .appleHealth,
        appleHealthWorkoutCount: Int? = nil,
        onOpenCoach: @escaping (String?) -> Void,
        onOpenJourney: @escaping () -> Void = {},
        onOpenPlan: @escaping () -> Void = {}
    ) {
        self.state = state
        self.actionCoordinator = actionCoordinator
        self.onOpenCoach = onOpenCoach
        self.onOpenJourney = onOpenJourney
        self.onOpenPlan = onOpenPlan
    }

    private var showsGenericCoachCTA: Bool {
        TodayCoachCTAPolicy.showsGenericCoachCTA(
            foodEntries: state.meals.entries,
            nextBestAction: state.nextBestAction
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.zoneSpacing) {
            statusZone

            TodayNextActionSection(
                action: state.nextBestAction,
                onPrimaryCTA: {
                    actionCoordinator.handleCTA(
                        state.nextBestAction.primaryCTA,
                        from: state.nextBestAction
                    )
                }
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

    private var statusZone: some View {
        VStack(alignment: .leading, spacing: TodayLayout.statusZoneSpacing) {
            TodayMissionHero(
                mission: state.mission,
                proteinProgress: state.macroBalance.macroSummary.protein,
                mealsEmpty: state.meals.isEmpty
            )

            if let goalConnection = state.goalConnection {
                TodayGoalConnectionRow(
                    connection: goalConnection,
                    onOpenJourney: onOpenJourney,
                    onOpenPlan: onOpenPlan
                )
            }
        }
    }

    private var loggedItemsZone: some View {
        VStack(alignment: .leading, spacing: TodayLayout.loggedZoneSpacing) {
            TodayReadOnlyProgressSection(
                macros: state.macroBalance.macroSummary,
                water: state.macroBalance.waterSummary
            )

            TodayMealsPreview(
                entries: state.meals.entries,
                date: state.date,
                onAddMeal: { mealType in
                    actionCoordinator.logMeal(for: mealType)
                },
                onEditEntry: { entry in
                    actionCoordinator.openEditFood(entry)
                },
                onDeleteEntry: { entry in
                    actionCoordinator.requestDeleteFood(entry)
                }
            )

            TodayActivitySection(
                activity: state.activity,
                onConnectAppleHealth: {
                    actionCoordinator.onOpenTrainingInsights?()
                }
            )

            TodayMomentumSection(momentum: state.momentum)

            TodayDailySummarySection(scorecard: state.dailyScorecard)

            TodayCoachTipSection(tip: state.aiCoachTip) { prefill in
                onOpenCoach(prefill)
            }
        }
    }
}

#Preview {
    ScrollView {
        TodayReadOnlyView(
            state: TodayPreviewData.state,
            actionCoordinator: TodayActionCoordinator(
                actionCenter: try! AppContainer(inMemory: true).actionCenter
            ),
            onOpenCoach: { _ in }
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
