//
//  OnboardingSavePlanSummaryCard.swift
//  Fitness Coach
//
//  Forma — Personalized plan artifact on the save-plan completion screen.
//

import SwiftUI

struct OnboardingSavePlanSummaryCard: View {
    let state: OnboardingPlanRevealState
    let metrics: OnboardingSavePlanLayoutMetrics

    private let copy = FormaProductCopy.Onboarding.V2.SavePlan.self

    private var metricChips: [String] {
        var chips: [String] = [state.dailyCalorieLabel]
        if let paceLabel = state.paceLabel {
            chips.append(paceLabel)
        }
        if let estimatedWeeksLabel = state.estimatedWeeksLabel {
            chips.append(estimatedWeeksLabel)
        }
        if !state.proteinLabel.isEmpty {
            chips.append(state.proteinLabel)
        }
        return chips
    }

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.isVeryCompactHeight ? 6 : FormaTokens.Spacing.xs) {
            headerRow

            Text(state.goalHeroHeadline)
                .font(metrics.planGoalFont)
                .foregroundStyle(OnboardingTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)

            journeyRow

            chipSection
        }
        .padding(metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { OnboardingPlanRevealCardBackground(surface: .goalHero) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.xs) {
            OnboardingPlanRevealSectionHeader(title: copy.planSummaryCardTitle, usesHeaderTrait: false)
                .foregroundStyle(OnboardingTheme.accent)
                .tracking(0.5)

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(OnboardingTheme.accent.opacity(0.14))
                    .frame(width: metrics.completionIconSize, height: metrics.completionIconSize)

                Image(systemName: "flag.checkered")
                    .font(.system(size: metrics.completionIconSize * 0.42, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.accent)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityHidden(true)
        }
    }

    private var journeyRow: some View {
        HStack(spacing: 4) {
            Text(copy.planSummaryJourneyLabel.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(state.goalProgressLabel)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    @ViewBuilder
    private var chipSection: some View {
        if metrics.isCompactWidth || metrics.usesAccessibilityLayout {
            VStack(alignment: .leading, spacing: 6) {
                adaptiveChipRows
            }
        } else {
            CoachFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(metricChips, id: \.self) { chip in
                    planChip(chip)
                }
            }
        }
    }

    @ViewBuilder
    private var adaptiveChipRows: some View {
        let pairs = metricChips.chunked(into: 2)
        ForEach(Array(pairs.enumerated()), id: \.offset) { _, row in
            HStack(spacing: 6) {
                ForEach(row, id: \.self) { chip in
                    planChip(chip)
                }
                if row.count == 1 {
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func planChip(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(OnboardingTheme.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                Capsule(style: .continuous)
                    .fill(FormaTokens.Color.surfaceSubtle.opacity(0.9))
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(OnboardingTheme.border.opacity(0.5), lineWidth: 1)
            }
    }

    private var accessibilitySummary: String {
        [
            copy.planSummaryCardTitle,
            state.goalHeroHeadline,
            "\(copy.planSummaryJourneyLabel) \(state.goalProgressLabel)",
            metricChips.joined(separator: ", ")
        ].joined(separator: ". ")
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#if DEBUG
#Preview {
    OnboardingSavePlanSummaryCard(
        state: OnboardingPreviewData.planRevealState!,
        metrics: OnboardingSavePlanLayoutMetrics(
            size: CGSize(width: 390, height: 844),
            dynamicTypeSize: .large
        )
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
