//
//  JourneyHabitInsightsSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyHabitInsightsSection: View {
    let state: JourneyHabitInsightsState
    var onCTA: ((JourneyCTA) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: FormaProductCopy.Journey.HabitInsights.sectionTitle)

            if state.isUnlocked {
                unlockedContent
            } else {
                lockedContent
            }
        }
    }

    private var lockedContent: some View {
        FitPilotPlanCard {
            Text(state.lockedMessage ?? FormaProductCopy.Journey.HabitInsights.lockedBody)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var unlockedContent: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            habitCard(
                eyebrow: FormaProductCopy.Journey.HabitInsights.strongestTitle,
                habitLabel: state.strongestHabitLabel,
                percent: state.strongestScorePercent,
                percentPrefix: nil,
                qualitative: state.strongestQualitative,
                accent: FormaTokens.Color.success
            )

            habitCard(
                eyebrow: FormaProductCopy.Journey.HabitInsights.nextFocusTitle,
                habitLabel: state.weakestHabitLabel,
                percent: state.weakestScorePercent,
                percentPrefix: state.weakestScorePrefix,
                qualitative: nil,
                accent: FormaTokens.Color.accent
            )

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                    Text(FormaProductCopy.Journey.HabitInsights.suggestionTitle)
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textTertiary)

                    Text(state.suggestedNextAction)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let cta = state.suggestionCTA, let onCTA {
                        JourneyCTAButton(cta: cta) {
                            onCTA(cta)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func habitCard(
        eyebrow: String,
        habitLabel: String,
        percent: Int,
        percentPrefix: String?,
        qualitative: String?,
        accent: Color
    ) -> some View {
        FitPilotPlanCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                Text(eyebrow)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textTertiary)

                Text(habitLabel)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)

                HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
                    if let percentPrefix {
                        Text(percentPrefix)
                            .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                    }

                    Text("\(percent)%")
                        .font(FormaTokens.Typography.sectionTitle)
                        .foregroundStyle(accent)

                    if let qualitative {
                        Text(qualitative)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(
            eyebrow: eyebrow,
            habitLabel: habitLabel,
            percent: percent,
            percentPrefix: percentPrefix,
            qualitative: qualitative
        ))
    }

    private func accessibilityLabel(
        eyebrow: String,
        habitLabel: String,
        percent: Int,
        percentPrefix: String?,
        qualitative: String?
    ) -> String {
        var parts = ["\(eyebrow). \(habitLabel)."]
        if let percentPrefix {
            parts.append("\(percentPrefix) \(percent) percent.")
        } else {
            parts.append("\(percent) percent.")
        }
        if let qualitative {
            parts.append(qualitative)
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Previews

#Preview("Unlocked") {
    JourneyHabitInsightsSection(state: ProgressPreviewData.habitInsightsActive)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Week one unlocked") {
    JourneyHabitInsightsSection(state: ProgressPreviewData.habitInsightsWeekOne)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Locked") {
    JourneyHabitInsightsSection(state: .locked)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
