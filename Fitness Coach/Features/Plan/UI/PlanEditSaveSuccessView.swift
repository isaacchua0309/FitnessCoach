//
//  PlanEditSaveSuccessView.swift
//  Fitness Coach
//
//  Forma — Brief save confirmation for Edit Plan.
//

import SwiftUI

struct PlanEditSaveSuccessView: View {
    let state: PlanEditSaveSuccessState

    @State private var showsCheckmark = false

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
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)

            Spacer(minLength: FormaTokens.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FormaPlanTokens.Color.planBackground.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.accessibilitySummary)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                showsCheckmark = true
            }
        }
    }

    private var checkmarkIcon: some View {
        ZStack {
            Circle()
                .fill(FormaPlanTokens.Color.planSuccess.opacity(0.14))
                .frame(width: 88, height: 88)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(FormaPlanTokens.Color.planSuccess)
                .scaleEffect(showsCheckmark ? 1 : 0.55)
                .opacity(showsCheckmark ? 1 : 0)
                .symbolEffect(.bounce, value: showsCheckmark)
        }
        .accessibilityHidden(true)
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
