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
    let onLogMealFromPreview: () -> Void

    init(
        state: TodayDashboardState,
        actionCoordinator: TodayActionCoordinator,
        trainingIntegration: TrainingIntegrationState = .connected,
        trainingDataSource: TrainingDataSource = .appleHealth,
        appleHealthWorkoutCount: Int? = nil,
        onOpenCoach: @escaping (String?) -> Void,
        onLogMealFromPreview: @escaping () -> Void = {}
    ) {
        self.state = state
        self.actionCoordinator = actionCoordinator
        self.onOpenCoach = onOpenCoach
        self.onLogMealFromPreview = onLogMealFromPreview
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
        TodayMissionHero(
            mission: state.mission,
            proteinProgress: state.macroBalance.macroSummary.protein,
            mealsEmpty: state.meals.isEmpty
        )
    }

    private var loggedItemsZone: some View {
        VStack(alignment: .leading, spacing: TodayLayout.loggedZoneSpacing) {
            TodayReadOnlyProgressSection(
                macros: state.macroBalance.macroSummary,
                water: state.macroBalance.waterSummary
            )

            TodayMealsPreview(
                entries: state.meals.entries,
                previewLimit: 3,
                onLogMeal: onLogMealFromPreview
            )
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
