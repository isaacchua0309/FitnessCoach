//
//  OnboardingPlanRevealJourneyCard.swift
//  Fitness Coach
//
//  Forma — Journey, pace, and belief for plan reveal.
//

import SwiftUI

struct OnboardingPlanRevealJourneyCard: View {
    let sectionTitle: String
    let progressLabel: String
    let paceLabel: String?
    let estimatedWeeksLabel: String?
    let beliefLine: String
    let planStatus: OnboardingPlanRevealStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            OnboardingPlanRevealSectionHeader(title: sectionTitle)

            journeyPath

            if let metricsLine = paceMetricsLine {
                Text(metricsLine)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.accent)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(beliefLine)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let planStatus, planStatus.style == .caution {
                cautionLine(planStatus)
            }
        }
        .onboardingPlanRevealCardPadding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { OnboardingPlanRevealCardBackground(surface: .standard) }
        .onboardingPlanRevealEntrance(.journey)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var journeyPath: some View {
        HStack(spacing: FormaTokens.Spacing.xs) {
            Text(progressLabel)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var paceMetricsLine: String? {
        switch (paceLabel, estimatedWeeksLabel) {
        case let (pace?, weeks?):
            return "\(pace) · \(weeks)"
        case let (pace?, nil):
            return pace
        case let (nil, weeks?):
            return weeks
        case (nil, nil):
            return nil
        }
    }

    private func cautionLine(_ status: OnboardingPlanRevealStatus) -> some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2.weight(.semibold))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                if let body = status.body {
                    Text(body)
                        .font(.caption2)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                }
            }
        }
        .foregroundStyle(OnboardingTheme.warning)
        .padding(.top, 2)
        .accessibilityLabel(
            [status.title, status.body].compactMap { $0 }.joined(separator: ", ")
        )
    }

    private var accessibilityLabel: String {
        var parts = [sectionTitle, progressLabel]
        if let paceMetricsLine {
            parts.append(paceMetricsLine)
        }
        parts.append(beliefLine)
        if let planStatus, planStatus.style == .caution {
            parts.append(planStatus.title)
            if let body = planStatus.body {
                parts.append(body)
            }
        }
        return parts.joined(separator: ", ")
    }
}

#if DEBUG
#Preview {
    OnboardingPlanRevealJourneyCard(
        sectionTitle: FormaProductCopy.Onboarding.V2.PlanReveal.Cards.journeyTitle,
        progressLabel: "82.5 kg → 75 kg",
        paceLabel: "0.5 kg/week",
        estimatedWeeksLabel: "About 15 weeks",
        beliefLine: "Moderate cut — a pace you chose, realistic and sustainable.",
        planStatus: nil
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
