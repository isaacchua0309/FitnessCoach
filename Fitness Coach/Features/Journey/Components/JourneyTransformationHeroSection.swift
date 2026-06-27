//
//  JourneyTransformationHeroSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyTransformationHeroSection: View {
    let state: JourneyTransformationState
    let nextCheckpointKg: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            JourneySectionLabel(title: FormaProductCopy.Journey.sectionGoalProgress)

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

                    weightMetricsRow

                    if let nextCheckpointKg {
                        Text(FormaProductCopy.Journey.nextCheckpoint(
                            ProgressFormatter.journeyKg(nextCheckpointKg)
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
    }

    private var weightMetricsRow: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            weightMetric(
                label: FormaProductCopy.Journey.metricCurrent,
                value: ProgressFormatter.journeyKg(state.currentWeightKg)
            )
            weightMetric(
                label: FormaProductCopy.Journey.metricGoal,
                value: ProgressFormatter.journeyKg(state.goalWeightKg)
            )
            if let toGo = toGoValue {
                weightMetric(label: FormaProductCopy.Journey.metricToGo, value: toGo)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(weightMetricsAccessibilityLabel)
    }

    private var toGoValue: String? {
        guard let current = state.currentWeightKg,
              let goal = state.goalWeightKg,
              abs(current - goal) > 0.05 else { return nil }
        return ProgressFormatter.journeyKg(abs(current - goal))
    }

    private var weightMetricsAccessibilityLabel: String {
        let current = ProgressFormatter.journeyKg(state.currentWeightKg)
        let goal = ProgressFormatter.journeyKg(state.goalWeightKg)
        if let toGo = toGoValue {
            return "Current weight \(current), goal \(goal), \(toGo) to go"
        }
        return "Current weight \(current), goal \(goal)"
    }

    private func weightMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)

            Text(value)
                .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
