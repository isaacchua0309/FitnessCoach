//
//  OnboardingPlanRevealFirstWeekCard.swift
//  Fitness Coach
//
//  Forma — First-week mission actions for plan reveal.
//

import SwiftUI

struct OnboardingPlanRevealFirstWeekCard: View {
    let sectionTitle: String
    let missions: [OnboardingPlanRevealMission]

    @ScaledMetric(relativeTo: .caption) private var iconSize: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(sectionTitle.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .tracking(0.4)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(missions) { mission in
                    missionRow(mission)
                }
            }
        }
        .padding(OnboardingLayout.compactCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OnboardingTheme.cardBackground())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(sectionTitle), \(missions.map(\.title).joined(separator: ", "))"
        )
    }

    private func missionRow(_ mission: OnboardingPlanRevealMission) -> some View {
        HStack(spacing: FormaTokens.Spacing.xs) {
            Image(systemName: mission.icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)

            Text(mission.title)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(OnboardingTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mission.title)
    }
}

#if DEBUG
#Preview {
    OnboardingPlanRevealFirstWeekCard(
        sectionTitle: FormaProductCopy.Onboarding.V2.PlanReveal.Cards.firstWeekTitle,
        missions: [
            OnboardingPlanRevealMission(icon: "fork.knife", title: "Log 4 meals this week"),
            OnboardingPlanRevealMission(icon: "figure.strengthtraining.traditional", title: "Hit protein most days"),
            OnboardingPlanRevealMission(icon: "scalemass", title: "Weigh in twice")
        ]
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
