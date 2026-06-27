//
//  OnboardingJourneyHeroCard.swift
//  Fitness Coach
//
//  Forma — Journey-first hero for onboarding plan reveal.
//

import SwiftUI

struct OnboardingJourneyHeroCard: View {
    let state: OnboardingPlanRevealState

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            sectionLabel

            weightJourneyRow

            if let weeklyChangeLabel = state.weeklyChangeLabel {
                timelineRow(icon: "speedometer", text: weeklyChangeLabel)
            }

            if let estimatedWeeksLabel = state.estimatedWeeksLabel {
                timelineRow(icon: "calendar", text: estimatedWeeksLabel)
            }

            Text(state.journeySummaryLine)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onboardingCard(selected: true)
        .accessibilityElement(children: .contain)
    }

    private var sectionLabel: some View {
        Label {
            Text(FormaProductCopy.Onboarding.V2.PlanReveal.journeySectionTitle)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
        } icon: {
            Image(systemName: "arrow.triangle.swap")
                .accessibilityHidden(true)
        }
        .labelStyle(.titleAndIcon)
        .foregroundStyle(OnboardingTheme.accent)
        .accessibilityAddTraits(.isHeader)
    }

    private var weightJourneyRow: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            weightColumn(label: "Current", value: state.currentWeightLabel)

            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .accessibilityHidden(true)

            weightColumn(label: "Goal", value: state.goalWeightLabel)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(journeyAccessibilityLabel)
    }

    private func weightColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.tertiaryText)

            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timelineRow(icon: String, text: String) -> some View {
        Label {
            Text(text)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .accessibilityHidden(true)
        }
        .labelStyle(.titleAndIcon)
        .foregroundStyle(OnboardingTheme.accent)
        .accessibilityLabel(text)
    }

    private var journeyAccessibilityLabel: String {
        var parts = [
            "Current weight \(state.currentWeightLabel)",
            "Goal weight \(state.goalWeightLabel)"
        ]
        if let weeklyChangeLabel = state.weeklyChangeLabel {
            parts.append(weeklyChangeLabel)
        }
        if let estimatedWeeksLabel = state.estimatedWeeksLabel {
            parts.append(estimatedWeeksLabel)
        }
        return parts.joined(separator: ". ")
    }
}

#Preview {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingJourneyHeroCard(state: state)
            .padding()
            .background(OnboardingTheme.background)
            .preferredColorScheme(.dark)
    }
}
