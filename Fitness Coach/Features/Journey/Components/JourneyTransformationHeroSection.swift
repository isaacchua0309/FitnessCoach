//
//  JourneyTransformationHeroSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyTransformationHeroSection: View {
    let state: JourneyTransformationState
    let milestones: [JourneyMilestone]

    var body: some View {
        FitPilotPlanCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
                HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                    Text(state.goalTitle)
                        .font(FormaTokens.Typography.screenTitle)
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: FormaTokens.Spacing.xs)

                    phaseBadge
                }

                Text(state.startedLabel)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)

                Text(weightRangeLine)
                    .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .accessibilityLabel(weightRangeAccessibilityLabel)

                if let remaining = ProgressFormatter.remainingKg(
                    current: state.currentWeightKg,
                    goal: state.goalWeightKg
                ) {
                    Text(remaining)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                        .foregroundStyle(FormaTokens.Color.textLegal)
                }

                if let nextMilestone = ProgressFormatter.nextMilestone(from: milestones) {
                    Text(FormaProductCopy.Journey.nextMilestone(
                        ProgressFormatter.journeyKg(nextMilestone.weightKg)
                    ))
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                }

                progressSection

                if let eta = state.estimatedCompletionLabel {
                    Text("Estimated \(eta)")
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                }
            }
        }
    }

    private var weightRangeLine: String {
        let current = ProgressFormatter.journeyKg(state.currentWeightKg)
        let goal = ProgressFormatter.journeyKg(state.goalWeightKg)
        return "\(current) → \(goal)"
    }

    private var weightRangeAccessibilityLabel: String {
        let current = ProgressFormatter.journeyKg(state.currentWeightKg)
        let goal = ProgressFormatter.journeyKg(state.goalWeightKg)
        return "Current weight \(current), goal \(goal)"
    }

    @ViewBuilder
    private var progressSection: some View {
        if state.progressPercent != nil || state.goalWeightKg != nil {
            let progress = state.progressPercent ?? 0
            let barValue = progress > 0 ? min(progress, 100) / 100 : 0.02

            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                SwiftUI.ProgressView(value: barValue)
                    .tint(FormaTokens.Color.accent)

                if progress < 1 {
                    Text(FormaProductCopy.Journey.progressEarlyDays)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 2)
        }
    }

    private var phaseBadge: some View {
        Text(state.currentPhase)
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(FormaTokens.Color.accent)
            .padding(.horizontal, FormaTokens.Spacing.xs + 2)
            .padding(.vertical, 4)
            .background(FormaTokens.Color.accentMuted)
            .clipShape(Capsule())
            .accessibilityLabel("Phase: \(state.currentPhase)")
    }
}
