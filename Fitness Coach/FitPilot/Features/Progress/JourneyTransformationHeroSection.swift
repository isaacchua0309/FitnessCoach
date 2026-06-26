//
//  JourneyTransformationHeroSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyTransformationHeroSection: View {
    let state: JourneyTransformationState

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            Text(state.goalTitle)
                .font(FormaTokens.Typography.screenTitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)

            Text(state.startedLabel)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xl) {
                weightColumn("Current", state.currentWeightKg)
                weightColumn("Goal", state.goalWeightKg)
            }

            if let progress = state.progressPercent {
                SwiftUI.ProgressView(value: min(progress, 100) / 100)
                    .tint(FormaTokens.Color.accent)
            }

            HStack {
                if let eta = state.estimatedCompletionLabel {
                    meta("Estimated", eta)
                }
                Spacer()
                meta("Phase", state.currentPhase)
            }

            VStack(alignment: .leading, spacing: 6) {
                FormaSectionLabel(title: "Coach")
                Text(state.coachInsight)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textLegal)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weightColumn(_ label: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textSecondary)
            Text(formatKg(value))
                .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
        }
    }

    private func meta(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
            Text(value)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textPrimary)
        }
    }

    private func formatKg(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))kg"
            : String(format: "%.1fkg", value)
    }
}
