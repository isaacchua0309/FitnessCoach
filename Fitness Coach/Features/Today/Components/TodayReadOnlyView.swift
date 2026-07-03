//
//  TodayReadOnlyView.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only Today dashboard. Mutations route through TodayActionCoordinator.
//
//  Section order: Mission → Daily Victory → Next Best Action → Smart Coach
//  → Quick Actions → Meals → Activity → Nutrition → End-of-Day Wrap-Up
//

import SwiftUI

struct TodayReadOnlyView: View {
    let state: TodayDashboardState
    let actionCoordinator: TodayActionCoordinator
    let onOpenJourney: () -> Void
    let onOpenPlan: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var sectionSpacing: CGFloat {
        verticalSizeClass == .compact
            ? FormaTokens.Spacing.lg
            : TodayLayout.sectionSpacing
    }

    init(
        state: TodayDashboardState,
        actionCoordinator: TodayActionCoordinator,
        trainingIntegration: TrainingIntegrationState = .connected,
        trainingDataSource: TrainingDataSource = .appleHealth,
        appleHealthWorkoutCount: Int? = nil,
        onOpenJourney: @escaping () -> Void = {},
        onOpenPlan: @escaping () -> Void = {}
    ) {
        self.state = state
        self.actionCoordinator = actionCoordinator
        self.onOpenJourney = onOpenJourney
        self.onOpenPlan = onOpenPlan
    }

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            missionBlock

            TodayVictorySection(victory: state.victory)

            TodayNextActionSection(
                action: state.nextBestAction,
                onPrimaryCTA: {
                    actionCoordinator.handleCTA(
                        state.nextBestAction.primaryCTA,
                        from: state.nextBestAction
                    )
                },
                onSecondaryCTA: { cta in
                    actionCoordinator.handleCTA(cta, from: state.nextBestAction)
                },
                onViewed: {
                    actionCoordinator.logNextActionViewed(for: state.nextBestAction)
                }
            )

            TodaySmartCoachBanner(
                smartCoach: state.smartCoach,
                onOpenCoach: { prefill in
                    actionCoordinator.onOpenCoach?(prefill)
                }
            )

            TodayQuickActionsSection(
                menuItems: state.quickActions.items,
                onSelect: { kind in
                    actionCoordinator.performQuickAction(kind)
                }
            )

            TodayMealsPreview(
                entries: state.meals.entries,
                date: state.date,
                mealsEmptyKind: state.emptyContext.mealsEmptyKind,
                onAddMeal: { mealType in
                    actionCoordinator.logMeal(for: mealType)
                },
                onEditEntry: { entry in
                    actionCoordinator.openEditFood(entry)
                },
                onDeleteEntry: { entry in
                    actionCoordinator.requestDeleteFood(entry)
                },
                onLogFirstMeal: {
                    actionCoordinator.performQuickAction(.manualEntry)
                }
            )

            TodayActivitySection(
                activity: state.activity,
                onConnectAppleHealth: {
                    actionCoordinator.onOpenTrainingInsights?()
                }
            )

            TodayReadOnlyProgressSection(
                macros: state.macroHydration.macroSummary,
                water: state.macroHydration.waterSummary,
                calorieSummary: state.mission.calorieSummary
            )

            TodayEndOfDayWrapUpSection(
                wrapUp: state.endOfDay,
                onOpenJourney: onOpenJourney
            )
        }
    }

    private var missionBlock: some View {
        VStack(alignment: .leading, spacing: TodayLayout.statusZoneSpacing) {
            TodayMissionHero(
                mission: state.mission,
                onLogMeal: {
                    actionCoordinator.performQuickAction(.manualEntry)
                }
            )

            if state.emptyContext.showsWeightReminder {
                TodayInlineEmptyCard(
                    copy: TodayEmptyStateFormatting.copy(for: .noRecentWeight),
                    onAction: {
                        actionCoordinator.performQuickAction(.logWeight)
                    }
                )
            }

            if let goalConnection = state.goalConnection {
                TodayGoalConnectionRow(
                    connection: goalConnection,
                    onOpenJourney: onOpenJourney,
                    onOpenPlan: onOpenPlan,
                    onTapped: { destination in
                        actionCoordinator.logGoalConnectionTapped(destination: destination)
                    }
                )
            }
        }
    }
}

#Preview("Partial day") {
    ScrollView {
        TodayReadOnlyView(
            state: TodayPreviewData.state,
            actionCoordinator: TodayActionCoordinator(
                actionCenter: try! AppContainer(inMemory: true).actionCenter
            )
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("New day") {
    ScrollView {
        TodayReadOnlyView(
            state: TodayPreviewData.emptyDay,
            actionCoordinator: TodayActionCoordinator(
                actionCenter: try! AppContainer(inMemory: true).actionCenter
            )
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Complete day") {
    ScrollView {
        TodayReadOnlyView(
            state: TodayPreviewData.completeDay,
            actionCoordinator: TodayActionCoordinator(
                actionCenter: try! AppContainer(inMemory: true).actionCenter
            )
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
