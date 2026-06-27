//
//  OnboardingJourneyHeroCard.swift
//  Fitness Coach
//
//  Forma — Compact goal journey summary for onboarding plan reveal.
//

import SwiftUI

struct OnboardingPlanJourneySummary: View {
    let state: OnboardingPlanRevealState

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(FormaProductCopy.Onboarding.V2.PlanReveal.journeySectionTitle)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .accessibilityAddTraits(.isHeader)

            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                Text(state.currentWeightLabel)
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .accessibilityHidden(true)

                Text(state.goalWeightLabel)
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(journeyAccessibilityLabel)

            if let timelineLine = compactTimelineLine {
                Text(timelineLine)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(timelineLine)
            }
        }
        .onboardingCompactCard()
    }

    private var compactTimelineLine: String? {
        let parts = [state.estimatedWeeksLabel, compactPaceLabel]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    private var compactPaceLabel: String? {
        guard let weeklyChangeLabel = state.weeklyChangeLabel else { return nil }
        return weeklyChangeLabel.replacingOccurrences(of: "Expected pace: ", with: "")
    }

    private var journeyAccessibilityLabel: String {
        var parts = [
            "Current weight \(state.currentWeightLabel)",
            "Goal weight \(state.goalWeightLabel)"
        ]
        if let timelineLine = compactTimelineLine {
            parts.append(timelineLine)
        }
        return parts.joined(separator: ". ")
    }
}

/// Legacy name retained for any existing references.
typealias OnboardingJourneyHeroCard = OnboardingPlanJourneySummary

#Preview {
    if let state = OnboardingPreviewData.planRevealState {
        OnboardingPlanJourneySummary(state: state)
            .padding()
            .background(OnboardingTheme.background)
            .preferredColorScheme(.dark)
    }
}
