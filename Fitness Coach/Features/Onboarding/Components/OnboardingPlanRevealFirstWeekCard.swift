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

    @Environment(\.onboardingPlanRevealIsCompactHeight) private var isCompactHeight
    @Environment(\.onboardingPlanRevealContentDensity) private var contentDensity
    @ScaledMetric(relativeTo: .caption) private var iconContainerSize: CGFloat = 24

    private var missionLineLimit: Int {
        (isCompactHeight || contentDensity != .standard) ? 1 : 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            OnboardingPlanRevealSectionHeader(title: sectionTitle)

            VStack(alignment: .leading, spacing: isCompactHeight ? 4 : OnboardingLayout.compactLabelGap) {
                ForEach(missions) { mission in
                    missionRow(mission)
                }
            }
        }
        .onboardingPlanRevealCardPadding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { OnboardingPlanRevealCardBackground(surface: .standard) }
        .onboardingPlanRevealEntrance(.firstWeek)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(sectionTitle), \(missions.map(\.title).joined(separator: ", "))"
        )
    }

    private func missionRow(_ mission: OnboardingPlanRevealMission) -> some View {
        HStack(spacing: FormaTokens.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(FormaTokens.Color.accentMuted)
                    .frame(width: iconContainerSize, height: iconContainerSize)

                Image(systemName: mission.icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.accent.opacity(0.92))
            }
            .accessibilityHidden(true)

            Text(mission.title)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(OnboardingTheme.primaryText)
                .lineLimit(missionLineLimit)
                .minimumScaleFactor(0.75)
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
