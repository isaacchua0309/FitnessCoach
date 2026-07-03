//
//  PlanDashboardContent.swift
//  Fitness Coach
//
//  Forma — Shared Plan section stack for PlanView and previews.
//

import SwiftUI

struct PlanDashboardContent: View {
    let state: PlanDashboardState
    var healthIntelligenceUIEnabled: Bool = false
    var planHealthIntelligenceSectionState: PlanHealthIntelligenceSectionState?
    var onGoToToday: (() -> Void)? = nil
    var onAdjustActivity: () -> Void = {}
    var onAdjustPlan: () -> Void = {}
    var onCalculationDetailsOpened: () -> Void = {}
    var onAppleHealthTap: (() -> Void)? = nil
    var onConnectHealth: (() -> Void)? = nil
    var onPlanHealthMissingDataAction: ((PlanHealthMissingDataActionState) -> Void)? = nil
    var healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator?
    var onSectionAppear: ((PlanProductSection) -> Void)? = nil

    private var showsHealthIntelligenceSection: Bool {
        PlanDashboardCompositionPolicy.showsHealthIntelligenceSection(
            isUIEnabled: healthIntelligenceUIEnabled,
            sectionState: planHealthIntelligenceSectionState
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.sectionSpacing) {
            primarySections

            VStack(alignment: .leading, spacing: PlanLayout.compactSectionSpacing) {
                secondarySections
            }
        }
        .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PlanLayout.horizontalPadding)
        .padding(.top, FormaTokens.Spacing.xs)
        .padding(.bottom, FormaMainTabLayout.scrollContentBottomPadding)
        .accessibilityIdentifier("plan-dashboard")
        .formaThemeReactive()
    }

    @ViewBuilder
    private var primarySections: some View {
        ForEach(PlanProductLayout.primarySectionOrder, id: \.self) { section in
            sectionView(for: section)
        }
    }

    @ViewBuilder
    private var secondarySections: some View {
        ForEach(PlanProductLayout.secondarySectionOrder, id: \.self) { section in
            sectionView(for: section)
        }
    }

    @ViewBuilder
    private func sectionView(for section: PlanProductSection) -> some View {
        switch section {
        case .header:
            PlanHeaderSection(state: state.header)

        case .goalProgress:
            PlanMissionControlHeroSection(strategy: state.strategy)
                .onAppear { onSectionAppear?(.goalProgress) }

        case .todayMission:
            PlanDailyTargetsSection(
                state: state.dailyTargets,
                onGoToToday: onGoToToday
            )
            .onAppear { onSectionAppear?(.todayMission) }

        case .planStatus:
            PlanStatusSection(state: state.status)

        case .whyThisWorks:
            PlanRationaleSection(
                explanation: state.explanation,
                onCalculationDetailsOpened: onCalculationDetailsOpened
            )
            .onAppear { onSectionAppear?(.whyThisWorks) }

        case .planConfidence:
            if showsHealthIntelligenceSection,
               let planHealthIntelligenceSectionState {
                PlanHealthIntelligenceSection(
                    state: planHealthIntelligenceSectionState,
                    healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator,
                    onMissingDataAction: onPlanHealthMissingDataAction,
                    onConnectHealth: onConnectHealth
                )
                .onAppear { onSectionAppear?(.planConfidence) }
                .accessibilityIdentifier("plan-health-intelligence-section")
            } else if PlanDashboardCompositionPolicy.showsLegacyPlanConfidenceSection(
                isUIEnabled: healthIntelligenceUIEnabled,
                sectionState: planHealthIntelligenceSectionState
            ) {
                // Legacy Apple Health confidence card — pending removal after Health Intelligence rollout.
                PlanConfidenceSection(
                    state: state.confidence,
                    onAppleHealthTap: onAppleHealthTap
                )
                .onAppear { onSectionAppear?(.planConfidence) }
            }

        case .whenToAdjust:
            PlanAdjustmentRulesSection(state: state.adjustmentRules)

        case .planAssumptions:
            PlanAssumptionsSection(
                state: state.assumptions,
                onAdjustActivity: onAdjustActivity
            )
            .onAppear { onSectionAppear?(.planAssumptions) }

        case .nextReview:
            PlanReviewSection(state: state.review)

        case .adjustPlanCTA:
            PlanAdjustPlanCTASection(
                state: state.adjustPlanCTA,
                onAdjustPlan: onAdjustPlan
            )
        }
    }
}
