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

            VStack(alignment: .leading, spacing: 10) {
                ForEach(achievements) { achievement in
                    HStack(spacing: 10) {
                        Text(achievement.isUnlocked ? "✓" : "○")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(achievement.isUnlocked ? .primary : .tertiary)
                        Text(achievement.title)
                            .font(.subheadline)
                            .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)
                    }
                }
            }
        }
    }
}
