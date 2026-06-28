//
//  JourneyTransformationHeroSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyTransformationHeroSection: View {
    let state: JourneyTransformationHeroState

    @ScaledMetric(relativeTo: .largeTitle) private var heroValueSize: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            statusRow

            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                Text(state.headlineCopy)
                    .font(FormaTokens.Typography.sectionTitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .accessibilityHidden(true)

                Text(state.changeValueCopy)
                    .font(.system(size: heroValueSize, weight: .bold, design: .rounded))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .accessibilityHidden(true)
            }

            progressBlock

            anchorColumns

            Text(state.paceForecastText)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private var statusRow: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            Text(state.emotionalStatusLabel)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.accent)
                .padding(.horizontal, FormaTokens.Spacing.sm)
                .padding(.vertical, 5)
                .background(FormaTokens.Color.accentMuted)
                .clipShape(Capsule())
                .accessibilityHidden(true)

            Spacer(minLength: FormaTokens.Spacing.xs)

            if state.streakChip.isVisible {
                Text(state.streakChip.label)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.success)
                    .padding(.horizontal, FormaTokens.Spacing.sm)
                    .padding(.vertical, 5)
                    .background(FormaTokens.Color.success.opacity(0.15))
                    .clipShape(Capsule())
                    .accessibilityHidden(true)
            }
        }
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            SwiftUI.ProgressView(value: progressBarFill)
                .tint(FormaTokens.Color.accent)
                .accessibilityLabel(FormaProductCopy.Journey.Transformation.progressAccessibilityLabel)
                .accessibilityValue(state.progressBarAccessibilityValue)

            Text(state.progressLabel)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.top, FormaTokens.Spacing.xs)
    }

    private var progressBarFill: Double {
        let percent = max(state.progressBarPercent, 0)
        if percent <= 0, state.goalWeightCopy != "—" {
            return 0.02
        }
        return min(percent, 100) / 100
    }

    private var anchorColumns: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            anchorColumn(
                title: FormaProductCopy.Journey.Transformation.columnStarted,
                value: state.startedWeightCopy,
                footnote: state.startedFootnote
            )
            anchorColumn(
                title: FormaProductCopy.Journey.Transformation.columnToday,
                value: state.todayWeightCopy,
                footnote: nil
            )
            anchorColumn(
                title: FormaProductCopy.Journey.Transformation.columnGoal,
                value: state.goalWeightCopy,
                footnote: nil
            )
        }
        .padding(.top, FormaTokens.Spacing.xs)
        .accessibilityHidden(true)
    }

    private func anchorColumn(title: String, value: String, footnote: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)

            Text(value)
                .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .minimumScaleFactor(0.85)
                .lineLimit(1)

            if let footnote {
                Text(footnote)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview("New user") {
    JourneyTransformationHeroSection(state: ProgressPreviewData.transformationNewUser)
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}

#Preview("Active fat loss") {
    JourneyTransformationHeroSection(state: ProgressPreviewData.transformationActiveFatLoss)
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}

#Preview("Near goal") {
    JourneyTransformationHeroSection(state: ProgressPreviewData.transformationNearGoal)
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}

#Preview("Gain goal") {
    JourneyTransformationHeroSection(state: ProgressPreviewData.transformationGainGoal)
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}

#Preview("Maintain goal") {
    JourneyTransformationHeroSection(state: ProgressPreviewData.transformationMaintainGoal)
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}
