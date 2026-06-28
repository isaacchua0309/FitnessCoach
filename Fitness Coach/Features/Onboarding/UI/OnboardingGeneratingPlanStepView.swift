//
//  OnboardingGeneratingPlanStepView.swift
//  Fitness Coach
//
//  Forma — Full-screen deterministic plan generation moment for onboarding v2.
//

import SwiftUI

struct OnboardingGeneratingPlanStepView: View {
    let viewState: OnboardingViewState
    let onReviewDetails: () -> Void

    @State private var revealedChecklistCount = 0

    private let checklist = FormaProductCopy.Onboarding.V2.Generating.checklist
    private let intervalsAfterReveal = OnboardingGeneratingPlanTiming.intervalsAfterReveal

    private var isGenerating: Bool {
        viewState == .generatingPlanAnimated
    }

    private var showsFailure: Bool {
        viewState == .generationFailed
    }

    var body: some View {
        VStack(spacing: OnboardingTheme.sectionSpacing) {
            Spacer(minLength: FormaTokens.Spacing.xl)

            header

            if showsFailure {
                failureContent
            } else {
                generatingContent
            }

            Spacer(minLength: FormaTokens.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: viewState) {
            await runChecklistAnimation()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            if isGenerating {
                SwiftUI.ProgressView()
                    .controlSize(.large)
                    .tint(OnboardingTheme.accent)
                    .accessibilityHidden(true)
            } else if showsFailure {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(OnboardingTheme.warning)
                    .accessibilityHidden(true)
            }

            Text(FormaProductCopy.Onboarding.V2.Generating.title)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Generating

    private var generatingContent: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            ForEach(Array(checklist.enumerated()), id: \.offset) { index, item in
                checklistRow(item: item, isComplete: index < revealedChecklistCount)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onboardingCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Plan preparation checklist")
    }

    private func checklistRow(item: String, isComplete: Bool) -> some View {
        Label {
            Text(item)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(
                    isComplete ? OnboardingTheme.primaryText : OnboardingTheme.secondaryText
                )
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(
                    isComplete ? OnboardingTheme.accent : OnboardingTheme.tertiaryText.opacity(0.8)
                )
                .accessibilityHidden(true)
        }
        .labelStyle(.titleAndIcon)
        .animation(
            .easeInOut(duration: OnboardingGeneratingPlanTiming.itemRevealAnimation),
            value: isComplete
        )
    }

    // MARK: - Failure

    private var failureContent: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            Text(FormaProductCopy.Onboarding.V2.Generating.failureMessage)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onReviewDetails) {
                Text(FormaProductCopy.Onboarding.V2.Generating.reviewDetailsCTA)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(OnboardingTheme.accent)
            .accessibilityLabel(FormaProductCopy.Onboarding.V2.Generating.reviewDetailsCTA)
        }
        .onboardingCard()
    }

    // MARK: - Animation

    @MainActor
    private func runChecklistAnimation() async {
        guard viewState == .generatingPlanAnimated else { return }
        OnboardingGeneratingPlanTiming.validateChecklistAlignment()
        revealedChecklistCount = 0

        try? await Task.sleep(
            nanoseconds: UInt64(OnboardingGeneratingPlanTiming.initialDelay * 1_000_000_000)
        )

        for (index, interval) in intervalsAfterReveal.enumerated() {
            guard !Task.isCancelled, viewState == .generatingPlanAnimated else { return }
            withAnimation(
                .easeInOut(duration: OnboardingGeneratingPlanTiming.itemRevealAnimation)
            ) {
                revealedChecklistCount = index + 1
            }
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }

        guard !Task.isCancelled, viewState == .generatingPlanAnimated else { return }
        try? await Task.sleep(
            nanoseconds: UInt64(OnboardingGeneratingPlanTiming.postCompleteHold * 1_000_000_000)
        )
    }
}

#Preview("Generating") {
    OnboardingGeneratingPlanStepView(
        viewState: .generatingPlanAnimated,
        onReviewDetails: {}
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Failed") {
    OnboardingGeneratingPlanStepView(
        viewState: .generationFailed,
        onReviewDetails: {}
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}
