//
//  JourneyWeeklyReviewSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyWeeklyReviewSection: View {
    let state: JourneyWeeklyHabitState
    var onCTA: ((JourneyCTA) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    if state.showsHabitRows {
                        ForEach(Array(state.habits.enumerated()), id: \.element.id) { index, habit in
                            if index > 0 {
                                FormaPlanRowDivider()
                            }
                            habitRow(habit)
                        }

                        if let cta = JourneyCTARouter.weeklyTrainingCTA(training: state.training),
                           let onCTA {
                            FormaPlanRowDivider()
                            JourneyCTAButton(cta: cta) {
                                onCTA(cta)
                            }
                        }
                    } else if let emptyMessage = state.emptyMessage {
                        Text(emptyMessage)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private func habitRow(_ habit: JourneyWeeklyHabitRowState) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                Text(habit.title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                    .foregroundStyle(FormaTokens.Color.textPrimary)

                Spacer(minLength: FormaTokens.Spacing.xs)

                Text(habit.weeklyCountLabel)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .multilineTextAlignment(.trailing)
            }

            if habit.showsDayProgress {
                dayProgressRow(habit.dayCells)
            }

            if let streakLabel = habit.streakLabel {
                Text(streakLabel)
                    .font(FormaTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(FormaTokens.Theme.primary)
            } else if let supportiveCopy = habit.supportiveCopy {
                Text(supportiveCopy)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
        }
        .padding(.vertical, FormaTokens.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private func dayProgressRow(_ cells: [Bool]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, isMet in
                Circle()
                    .fill(
                        isMet
                            ? FormaTokens.Color.progress
                            : FormaTokens.Color.border.opacity(0.55)
                    )
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Full week") {
    JourneyWeeklyReviewSection(state: JourneyPreviewData.strongMomentum.weeklyHabit)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Partial week") {
    JourneyWeeklyReviewSection(state: JourneyPreviewData.weekOne.weeklyHabit)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("New user empty") {
    JourneyWeeklyReviewSection(state: JourneyPreviewData.brandNewUser.weeklyHabit)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Apple Health locked") {
    JourneyWeeklyReviewSection(state: JourneyPreviewData.healthDisconnected.weeklyHabit)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
