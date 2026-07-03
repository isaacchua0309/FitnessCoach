//
//  PlanEditSaveSuccessView.swift
//  Fitness Coach
//
//  Forma — Brief save confirmation for Edit Plan.
//

import SwiftUI

struct PlanEditSaveSuccessView: View {
    let state: PlanEditSaveSuccessState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsCheckmark = false
    @State private var showsCopy = false

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.lg) {
            Spacer(minLength: FormaTokens.Spacing.xl)

            checkmarkIcon

            VStack(spacing: FormaTokens.Spacing.sm) {
                Text(state.title)
                    .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                    .multilineTextAlignment(.center)

                Text(state.trackLine)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(state.todayLine)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(showsCopy ? 1 : 0)
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)

            Spacer(minLength: FormaTokens.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FormaPlanTokens.Color.planBackground.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.accessibilitySummary)
        .planEditSupportsDynamicType()
        .onAppear {
            playSuccessAnimation()
            PlanEditAccessibility.announce(state.accessibilitySummary)
        }
    }

    private var checkmarkIcon: some View {
        ZStack {
            Circle()
                .fill(FormaPlanTokens.Color.planSuccessSoft)
                .frame(width: 88, height: 88)
                .scaleEffect(showsCheckmark ? 1 : 0.92)
                .opacity(showsCheckmark ? 1 : 0)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(FormaPlanTokens.Color.planSuccess)
                .scaleEffect(showsCheckmark ? 1 : 0.88)
                .opacity(showsCheckmark ? 1 : 0)
        }
        .accessibilityHidden(true)
    }

    private func playSuccessAnimation() {
        PlanEditMotion.withAnimationIfEnabled(PlanEditMotion.successReveal, reduceMotion: reduceMotion) {
            showsCheckmark = true
        }

        guard !reduceMotion else {
            showsCopy = true
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            PlanEditMotion.withAnimationIfEnabled(PlanEditMotion.successReveal, reduceMotion: reduceMotion) {
                showsCopy = true
            }
        }
    }
}

#Preview("Save success") {
    PlanEditSaveSuccessView(
        state: PlanEditSaveSuccessState(
            title: FormaProductCopy.PlanEditSave.planUpdatedTitle,
            trackLine: FormaProductCopy.PlanEditSave.onTrackForGoal("Lose fat", by: "March 2026"),
            todayLine: FormaProductCopy.PlanEditSave.todayTargetsRegenerated,
            accessibilitySummary: "Plan updated"
        )
    )
    .formaThemePreview()
}
