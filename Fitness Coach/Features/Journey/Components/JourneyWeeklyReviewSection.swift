//
//  JourneyWeeklyReviewSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyWeeklyReviewSection: View {
    let state: JourneyWeeklyHabitState
    var hidesTrainingHabitRow: Bool = false
    var hidesHabitRows: Bool = false
    var onCTA: ((JourneyCTA) -> Void)?

    private var visibleHabits: [JourneyWeeklyHabitRowState] {
        guard !hidesHabitRows else { return [] }
        guard hidesTrainingHabitRow else { return state.habits }
        return state.habits.filter { $0.id != "training" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            JourneySectionLabel(title: state.sectionTitle)

            JourneyCard(elevation: .standard) {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    if !visibleHabits.isEmpty {
                        ForEach(Array(visibleHabits.enumerated()), id: \.element.id) { index, habit in
                            if index > 0 {
                                FormaPlanRowDivider()
                            }
                            habitRow(habit)
                        }
                    }

                    if !hidesTrainingHabitRow,
                       let cta = JourneyCTARouter.weeklyTrainingCTA(training: state.training),
                       let onCTA {
                        if !visibleHabits.isEmpty {
                            FormaPlanRowDivider()
                        }
                        JourneyCTAButton(cta: cta) {
                            onCTA(cta)
                        }
                    } else if visibleHabits.isEmpty, let emptyMessage = state.emptyMessage {
                        Text(emptyMessage)
                            .font(JourneyTypography.cardSupporting)
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
        VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                Text(habit.title)
                    .font(JourneyTypography.metricLabel)
                    .foregroundStyle(FormaTokens.Color.textPrimary)

                Spacer(minLength: FormaTokens.Spacing.xs)

                Text(habit.weeklyCountLabel)
                    .font(JourneyTypography.cardSupporting.weight(.medium))
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .multilineTextAlignment(.trailing)
            }

            if habit.showsDayProgress {
                JourneyDayDotRow(cells: habit.dayCells)
            }

            if let streakLabel = habit.streakLabel {
                Text(streakLabel)
                    .font(FormaTokens.Typography.caption2.weight(.medium))
                    .foregroundStyle(FormaTokens.Theme.primary)
            } else if let supportiveCopy = habit.supportiveCopy {
                Text(supportiveCopy)
                    .font(FormaTokens.Typography.caption2)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, JourneyLayout.compactSpacing)
        .accessibilityElement(children: .combine)
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
