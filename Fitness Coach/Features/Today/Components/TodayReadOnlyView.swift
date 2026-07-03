//
//  TodayReadOnlyView.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only Today dashboard. Mutations route through TodayActionCoordinator.
//
//  Section order: Mission → [Health Intelligence] → Next Best Action → Quick Actions
//  → Meals → Activity → Nutrition
//

import SwiftUI

struct TodayReadOnlyView: View {
    let state: TodayDashboardState
    let actionCoordinator: TodayActionCoordinator
    let healthIntelligenceSection: TodayHealthIntelligenceSectionState?
    let isHealthIntelligenceUIEnabled: Bool
    let onHealthNextBestAction: ((TodayHealthNextBestActionDestination) -> Void)?
    let onOpenJourney: () -> Void
    let onOpenPlan: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var sectionSpacing: CGFloat {
        verticalSizeClass == .compact
            ? FormaTokens.Spacing.lg
            : TodayLayout.sectionSpacing
    }

    private var showsHealthIntelligence: Bool {
        TodayReadOnlyCompositionPolicy.showsHealthIntelligenceSection(
            isUIEnabled: isHealthIntelligenceUIEnabled,
            sectionState: healthIntelligenceSection
        )
    }

    private var showsLegacyNextBestAction: Bool {
        TodayReadOnlyCompositionPolicy.showsLegacyNextBestAction(
            isUIEnabled: isHealthIntelligenceUIEnabled,
            sectionState: healthIntelligenceSection
        )
    }

    private var showsActivitySection: Bool {
        TodayReadOnlyCompositionPolicy.showsActivitySection(
            isUIEnabled: isHealthIntelligenceUIEnabled,
            sectionState: healthIntelligenceSection,
            activity: state.activity
        )
    }

    init(
        state: TodayDashboardState,
        actionCoordinator: TodayActionCoordinator,
        healthIntelligenceSection: TodayHealthIntelligenceSectionState? = nil,
        isHealthIntelligenceUIEnabled: Bool = false,
        onHealthNextBestAction: ((TodayHealthNextBestActionDestination) -> Void)? = nil,
        onOpenJourney: @escaping () -> Void = {},
        onOpenPlan: @escaping () -> Void = {}
    ) {
        self.state = state
        self.actionCoordinator = actionCoordinator
        self.healthIntelligenceSection = healthIntelligenceSection
        self.isHealthIntelligenceUIEnabled = isHealthIntelligenceUIEnabled
        self.onHealthNextBestAction = onHealthNextBestAction
        self.onOpenJourney = onOpenJourney
        self.onOpenPlan = onOpenPlan
    }

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            missionBlock

            if showsHealthIntelligence, let healthIntelligenceSection {
                TodayHealthIntelligenceSection(
                    state: healthIntelligenceSection,
                    onNextBestAction: onHealthNextBestAction
                )
            }

            if showsLegacyNextBestAction {
                // Legacy next best action card — pending removal after Health Intelligence rollout.
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
            }

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
                }
            )

            if showsActivitySection {
                // Legacy activity/workout card — pending removal after Health Intelligence rollout.
                TodayActivitySection(
                    activity: state.activity,
                    onConnectAppleHealth: {
                        actionCoordinator.onOpenTrainingInsights?()
                    }
                )
            }

            TodayReadOnlyProgressSection(
                macros: state.macroHydration.macroSummary,
                water: state.macroHydration.waterSummary,
                calorieSummary: state.mission.calorieSummary
            )
        }
    }

    private var missionBlock: some View {
        VStack(alignment: .leading, spacing: TodayLayout.statusZoneSpacing) {
            TodayMissionHero(
                mission: state.mission,
                onLogMeal: {
                    actionCoordinator.performQuickAction(.logMeal)
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

#Preview("Health Intelligence enabled") {
    ScrollView {
        TodayReadOnlyView(
            state: TodayPreviewData.partialDay,
            actionCoordinator: TodayActionCoordinator(
                actionCenter: try! AppContainer(inMemory: true).actionCenter
            ),
            healthIntelligenceSection: TodayHealthIntelligencePreviewData.workoutDay,
            isHealthIntelligenceUIEnabled: true,
            onHealthNextBestAction: { _ in }
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
