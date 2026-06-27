//
//  JourneyAchievementsSection.swift
//  Fitness Coach
//
//  TODO: Intentionally hidden from the main Journey scroll (Option A cleanup).
//  Preserved for a future dedicated achievements surface — do not delete models
//  or JourneyStateBuilder.achievements until that screen ships.
//

import SwiftUI

struct JourneyAchievementsSection: View {
    let achievements: [JourneyAchievement]

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            JourneySectionLabel(title: "Achievements")

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                    ForEach(achievements) { achievement in
                        achievementRow(achievement)
                    }
                }
            }
        }
    }

    private func achievementRow(_ achievement: JourneyAchievement) -> some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            Image(systemName: achievement.isUnlocked ? "checkmark.circle.fill" : "circle")
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(
                    achievement.isUnlocked
                        ? FormaTokens.Color.success
                        : FormaTokens.Color.textTertiary
                )
                .symbolRenderingMode(.hierarchical)

            Text(achievement.title)
                .font(FormaTokens.Typography.sectionSubtitle.weight(achievement.isUnlocked ? .medium : .regular))
                .foregroundStyle(
                    achievement.isUnlocked
                        ? FormaTokens.Color.textPrimary
                        : FormaTokens.Color.textSecondary
                )

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .frame(minHeight: FitPilotScreenStyle.rowMinHeight, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            achievement.isUnlocked
                ? "\(achievement.title), \(FormaProductCopy.Journey.achievementUnlocked)"
                : "\(achievement.title), \(FormaProductCopy.Journey.achievementLocked)"
        )
    }
}

#if DEBUG
#Preview("Achievements (hidden from Journey)") {
    ScrollView {
        JourneyAchievementsSection(achievements: ProgressPreviewData.state.achievements)
            .padding()
    }
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
#endif
