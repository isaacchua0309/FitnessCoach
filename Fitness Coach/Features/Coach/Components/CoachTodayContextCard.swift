//
//  CoachTodayContextCard.swift
//  Fitness Coach
//
//  Forma — Compact today snapshot shown above Coach quick actions.
//

import SwiftUI

struct CoachTodayContextCard: View {
    let state: CoachTodayContextState

    var body: some View {
        MainTabCard {
            VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
                    ForEach(Array(todaySoFarLines.enumerated()), id: \.offset) { index, line in
                        Text(line.text)
                            .font(lineFont(for: line, index: index))
                            .foregroundStyle(lineColor(for: line, index: index))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                CoachContextDivider()

                VStack(alignment: .leading, spacing: CoachDesignTokens.Spacing.xxs) {
                    SectionLabel(
                        title: FormaProductCopy.Coach.suggestedNextSectionTitle,
                        style: .muted
                    )

                    Text(state.suggestedFocus)
                        .font(CoachDesignTokens.Typography.hint)
                        .foregroundStyle(CoachDesignTokens.Color.textLegal)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var todaySoFarLines: [CoachTodayContextLine] {
        var lines: [CoachTodayContextLine] = [
            .metric(state.caloriesLine, emphasized: true),
            .metric(state.proteinLine),
            .metric(state.waterLine)
        ]
        lines.append(contentsOf: state.activityLines.map { .metric($0) })
        if let hint = state.activityHintLine {
            lines.append(.hint(hint))
        }
        return lines
    }

    private func lineFont(for line: CoachTodayContextLine, index: Int) -> Font {
        switch line {
        case .metric(_, let emphasized) where emphasized || index == 0:
            return CoachDesignTokens.Typography.hint.weight(.medium)
        case .metric:
            return CoachDesignTokens.Typography.hint
        case .hint:
            return CoachDesignTokens.Typography.hint
        }
    }

    private func lineColor(for line: CoachTodayContextLine, index: Int) -> Color {
        switch line {
        case .metric(_, let emphasized) where emphasized || index == 0:
            return CoachDesignTokens.Color.primaryText
        case .metric:
            return CoachDesignTokens.Color.secondaryText
        case .hint:
            return CoachDesignTokens.Color.tertiaryText
        }
    }

    private var accessibilitySummary: String {
        let activity = (state.activityLines + [state.activityHintLine].compactMap { $0 })
            .joined(separator: ". ")
        return """
        \(FormaProductCopy.Coach.todaySoFarSectionTitle). \
        \(state.caloriesLine). \(state.proteinLine). \(state.waterLine). \
        \(activity). \
        \(FormaProductCopy.Coach.suggestedNextSectionTitle): \(state.suggestedFocus)
        """
    }
}

private enum CoachTodayContextLine: Equatable {
    case metric(String, emphasized: Bool = false)
    case hint(String)

    var text: String {
        switch self {
        case .metric(let text, _), .hint(let text):
            return text
        }
    }
}

private struct CoachContextDivider: View {
    var body: some View {
        Rectangle()
            .fill(CoachDesignTokens.Color.border.opacity(0.65))
            .frame(height: 1)
            .padding(.vertical, CoachDesignTokens.Spacing.xxs)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: FormaMainTabLayout.sectionLabelBottomSpacing) {
        SectionLabel(title: FormaProductCopy.Coach.todaySoFarSectionTitle)
        CoachTodayContextCard(
            state: CoachTodayContextState(
                caloriesLine: "0 eaten · 2,249 target",
                proteinLine: "Protein 0 / 180 g",
                waterLine: "Water 0 / 3150 ml",
                activityLines: [
                    "Latest: Chicken rice · 650 kcal",
                    "8,420 steps",
                    "Workout: Completed"
                ],
                activityHintLine: nil,
                suggestedFocus: FormaProductCopy.Today.focusProteinLow
            )
        )
    }
    .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
    .background(CoachDesignTokens.Color.background)
    .formaThemePreview()
}
