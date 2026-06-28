//
//  TodayReadOnlyView.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only Today dashboard. Mutations route through TodayActionCoordinator.
//
//  Section order: Mission → Next Best Action → Quick Actions → Meals → Activity
//  → Macro Balance → Momentum → Daily Summary → Coach Tip
//

import SwiftUI

struct TodayReadOnlyView: View {
    let state: TodayDashboardState
    let actionCoordinator: TodayActionCoordinator
    let onOpenCoach: (String?) -> Void
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

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            missionBlock

            TodayNextActionSection(
                action: state.nextBestAction,
                onPrimaryCTA: {
                    actionCoordinator.handleCTA(
                        state.nextBestAction.primaryCTA,
                        from: state.nextBestAction
                    )
                },
                onViewed: {
                    actionCoordinator.logNextActionViewed(for: state.nextBestAction)
                }
            )

            TodayQuickActionsSection(
                menuItems: TodayQuickActionPolicy.menuItems(),
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
                macros: state.macroBalance.macroSummary,
                water: state.macroBalance.waterSummary
            )

            TodayMomentumSection(momentum: state.momentum)

            TodayDailySummarySection(scorecard: state.dailyScorecard)

            TodayCoachTipSection(tip: state.aiCoachTip) { prefill in
                onOpenCoach(prefill)
            }
        }
    }

    private var missionBlock: some View {
        VStack(alignment: .leading, spacing: TodayLayout.statusZoneSpacing) {
            TodayMissionHero(
                mission: state.mission,
                proteinProgress: state.macroBalance.macroSummary.protein,
                mealsEmptyKind: state.emptyContext.mealsEmptyKind,
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
            ),
            onOpenCoach: { _ in }
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
            ),
            onOpenCoach: { _ in }
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
            ),
            onOpenCoach: { _ in }
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
