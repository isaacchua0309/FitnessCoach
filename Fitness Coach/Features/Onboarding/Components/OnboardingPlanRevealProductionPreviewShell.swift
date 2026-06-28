//
//  OnboardingPlanRevealProductionPreviewShell.swift
//  Fitness Coach
//
//  Forma — Full fixed-viewport shell for plan reveal previews and snapshots.
//

import SwiftUI

struct OnboardingPlanRevealProductionPreviewShell: View {
    let revealState: OnboardingPlanRevealState
    let plan: CalorieTargetResult
    var showsAllEntranceStages: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            OnboardingPlanRevealStepView(
                revealState: revealState,
                plan: plan,
                showsSuccessHandoff: true
            )
            .modifier(PlanRevealEntranceStagesModifier(enabled: showsAllEntranceStages))

            OnboardingBottomBar(
                currentStep: .planReveal,
                isLoading: false,
                canContinue: true,
                onBack: {},
                onContinue: {},
                onComplete: {},
                onAdjustPlan: {},
                saveTrustNote: FormaProductCopy.Onboarding.Flow.PlanReveal.signedOutSaveTrustNote
            )
        }
    }
}

private struct PlanRevealEntranceStagesModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.environment(
                \.onboardingPlanRevealVisibleStages,
                Set(OnboardingPlanRevealEntranceStage.allCases)
            )
        } else {
            content
        }
    }
}

#if DEBUG
#Preview("iPhone SE — Cut") {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanRevealProductionPreviewShell(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan
        )
        .frame(width: 375, height: 667)
        .background(OnboardingTheme.background)
        .formaThemePreview()
    }
}

#Preview("iPhone Pro Max — Cut") {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanRevealProductionPreviewShell(
            revealState: state,
            plan: OnboardingPreviewData.generatedPlan
        )
        .frame(width: 430, height: 932)
        .background(OnboardingTheme.background)
        .formaThemePreview()
    }
}

#Preview("iPhone SE — Maintain") {
    if let state = maintainPreviewState() {
        OnboardingPlanRevealProductionPreviewShell(
            revealState: state,
            plan: maintenancePreviewPlan()
        )
        .frame(width: 375, height: 667)
        .background(OnboardingTheme.background)
        .formaThemePreview()
    }
}

private func maintainPreviewState() -> OnboardingPlanRevealState? {
    var form = OnboardingPreviewData.formState
    form.goalWeightKgText = form.currentWeightKgText
    return OnboardingPlanRevealBuilder.build(
        formState: form,
        plan: maintenancePreviewPlan()
    )
}

private func maintenancePreviewPlan() -> CalorieTargetResult {
    CalorieTargetResult(
        estimatedBMR: 1480,
        estimatedTDEE: 2290,
        targets: UserTargets(
            calorieTarget: 2290,
            proteinTarget: 130,
            carbTarget: 250,
            fatTarget: 70,
            waterTargetMl: 2520,
            expectedWeeklyWeightLossKg: nil,
            aggressiveness: .moderate
        ),
        estimatedDailyDeficit: 0,
        isAggressive: false,
        warning: nil
    )
}
#endif
