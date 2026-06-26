//
//  JourneyAchievementsSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyAchievementsSection: View {
    let achievements: [JourneyAchievement]

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            JourneySectionLabel(title: "Achievements")

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs + 2) {
                    ForEach(achievements) { achievement in
                        HStack(spacing: FormaTokens.Spacing.xs + 2) {
                            Image(systemName: achievement.isUnlocked ? "checkmark.circle.fill" : "circle")
                                .font(FormaTokens.Typography.sectionSubtitle)
                                .foregroundStyle(achievement.isUnlocked ? FormaTokens.Color.success : FormaTokens.Color.textTertiary)
                            Text(achievement.title)
                                .font(FormaTokens.Typography.sectionSubtitle)
                                .foregroundStyle(achievement.isUnlocked ? FormaTokens.Color.textPrimary : FormaTokens.Color.textSecondary)
                        }
                        .frame(minHeight: FitPilotScreenStyle.rowMinHeight, alignment: .leading)
                    }
                }
            }
        }
    }
}
