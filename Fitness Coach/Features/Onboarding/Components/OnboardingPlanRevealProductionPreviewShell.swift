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
                showsSuccessHandoff: true,
                revealsEntranceImmediately: showsAllEntranceStages
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

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

#if DEBUG
private func planRevealProductionPreview(
    width: CGFloat,
    height: CGFloat,
    dynamicTypeSize: DynamicTypeSize? = nil
) -> some View {
    Group {
        if let state = OnboardingPreviewData.planRevealState {
            OnboardingPlanRevealProductionPreviewShell(
                revealState: state,
                plan: OnboardingPreviewData.generatedPlan
            )
            .frame(width: width, height: height)
            .background(OnboardingTheme.background)
            .formaThemePreview()
            .modifier(OptionalDynamicTypeSizeModifier(size: dynamicTypeSize))
        }
    }
}

private struct OptionalDynamicTypeSizeModifier: ViewModifier {
    let size: DynamicTypeSize?

    func body(content: Content) -> some View {
        if let size {
            content.dynamicTypeSize(size)
        } else {
            content
        }
    }
}

#Preview("iPhone SE") {
    planRevealProductionPreview(width: 375, height: 667)
}

#Preview("iPhone 13 mini") {
    planRevealProductionPreview(width: 375, height: 812)
}

#Preview("iPhone 15") {
    planRevealProductionPreview(width: 393, height: 852)
}

#Preview("iPhone 15 Pro") {
    planRevealProductionPreview(width: 393, height: 852)
}

#Preview("iPhone 15 Pro Max") {
    planRevealProductionPreview(width: 430, height: 932)
}

#Preview("Large text accessibility") {
    planRevealProductionPreview(width: 393, height: 852, dynamicTypeSize: .accessibility2)
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
