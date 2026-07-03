//
//  JourneyHealthIntelligenceSection.swift
//  Fitness Coach
//
//  Forma — Composes Journey Health Intelligence cards into a section stack.
//

import SwiftUI

struct JourneyHealthIntelligenceSection: View {
    let state: JourneyHealthIntelligenceSectionState
    var onConnectHealth: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.sectionSpacing) {
            if let connectCTA = state.connectHealthCTA {
                connectHealthCard(connectCTA)
            }

            if let weeklyReview = state.weeklyReviewPreview, weeklyReview.phase != .loading || state.isLoading {
                JourneyWeeklyReviewPreviewCard(
                    state: weeklyReview,
                    isLoading: state.isLoading
                )
            }

            JourneyRecoveryTimelineCard(
                state: state.recoveryTimeline,
                isLoading: state.isLoading,
                referenceDay: referenceDay
            )

            JourneyWorkoutHistoryCard(
                state: state.workoutHistory,
                isLoading: state.isLoading
            )

            JourneyMilestonesCard(
                state: state.milestones,
                isLoading: state.isLoading
            )

            JourneyHealthProgressCard(
                state: state.progress,
                isLoading: state.isLoading
            )
        }
        .formaThemeReactive()
    }

    private var referenceDay: Date? {
        state.recoveryTimeline.days.last?.date
    }

    @ViewBuilder
    private func connectHealthCard(_ cta: JourneyHealthConnectCTAState) -> some View {
        JourneyCard(elevation: .quiet) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(cta.title)
                    .font(JourneyTypography.cardHeadline)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(cta.message)
                    .font(JourneyTypography.cardSupporting)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let onConnectHealth {
                    Button(cta.ctaTitle, action: onConnectHealth)
                        .buttonStyle(.borderedProminent)
                        .tint(FormaTokens.Theme.primary)
                        .controlSize(.regular)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, JourneyLayout.compactSpacing)
                } else {
                    Text(cta.ctaTitle)
                        .font(JourneyTypography.cardHeadline)
                        .foregroundStyle(FormaTokens.Theme.primary)
                        .padding(.top, JourneyLayout.compactSpacing)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cta.accessibilityLabel)
    }
}

// MARK: - Weekly review preview card

private struct JourneyWeeklyReviewPreviewCard: View {
    let state: JourneyWeeklyReviewPreviewState
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            JourneySectionLabel(title: state.sectionTitle)

            JourneyHealthIntelligenceLoadingCard(isLoading: isLoading || state.phase == .loading) {
                JourneyCard(elevation: .standard) {
                    VStack(alignment: .leading, spacing: JourneyHealthIntelligenceCardSupport.cardContentSpacing) {
                        if !state.weekRangeLabel.isEmpty {
                            Text(state.weekRangeLabel)
                                .font(FormaTokens.Typography.caption2.weight(.semibold))
                                .foregroundStyle(FormaTokens.Color.textTertiary)
                                .textCase(.uppercase)
                                .tracking(0.4)
                        }

                        switch state.phase {
                        case .loading:
                            loadingContent
                        case .empty, .error:
                            phaseMessage
                        case .loaded:
                            loadedContent
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .formaThemeReactive()
    }

    @ViewBuilder
    private var loadingContent: some View {
        Text(state.title)
            .font(JourneyTypography.cardHeadline)
            .foregroundStyle(FormaTokens.Color.textPrimary)
        Text(state.summary)
            .font(JourneyTypography.cardSupporting)
            .foregroundStyle(FormaTokens.Color.textSecondary)
    }

    @ViewBuilder
    private var phaseMessage: some View {
        Text(state.summary)
            .font(JourneyTypography.cardSupporting)
            .foregroundStyle(
                state.phase == .error
                    ? FormaTokens.Color.warning
                    : FormaTokens.Color.textSecondary
            )
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var loadedContent: some View {
        Text(state.title)
            .font(JourneyTypography.cardHeadline)
            .foregroundStyle(FormaTokens.Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)

        Text(state.summary)
            .font(JourneyTypography.cardSupporting)
            .foregroundStyle(FormaTokens.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

        if !state.winLines.isEmpty {
            winLinesBlock
        }

        if !state.focusLines.isEmpty {
            focusLinesBlock
        }

        if let confidenceNote = state.confidenceNote {
            JourneyHealthIntelligencePhaseMessage(message: confidenceNote, tone: .caution)
        }
    }

    @ViewBuilder
    private var winLinesBlock: some View {
        FormaPlanRowDivider()

        VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
            Text("Wins")
                .font(FormaTokens.Typography.caption2.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .textCase(.uppercase)
                .tracking(0.4)

            ForEach(Array(state.winLines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(JourneyTypography.cardSupporting)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var focusLinesBlock: some View {
        FormaPlanRowDivider()

        VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
            Text("Focus")
                .font(FormaTokens.Typography.caption2.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .textCase(.uppercase)
                .tracking(0.4)

            ForEach(Array(state.focusLines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(JourneyTypography.cardSupporting)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Previews

#Preview("Strong week") {
    ScrollView {
        JourneyHealthIntelligenceSection(
            state: JourneyHealthIntelligencePreviewData.strongWeek
        )
        .padding(.horizontal, JourneyLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Connected — no workouts") {
    ScrollView {
        JourneyHealthIntelligenceSection(
            state: JourneyHealthIntelligencePreviewData.connectedNoWorkouts
        )
        .padding(.horizontal, JourneyLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Unavailable — connect health") {
    ScrollView {
        JourneyHealthIntelligenceSection(
            state: JourneyHealthIntelligencePreviewData.unavailable,
            onConnectHealth: {}
        )
        .padding(.horizontal, JourneyLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Loading") {
    ScrollView {
        JourneyHealthIntelligenceSection(
            state: JourneyHealthIntelligencePreviewData.loading
        )
        .padding(.horizontal, JourneyLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Theme matrix — Blossom Pink") {
    ScrollView {
        JourneyHealthIntelligenceSection(
            state: JourneyHealthIntelligencePreviewData.strongWeek
        )
        .padding(.horizontal, JourneyLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview(palette: .blossomPink)
}

#Preview("Dark mode") {
    ScrollView {
        JourneyHealthIntelligenceSection(
            state: JourneyHealthIntelligencePreviewData.strongWeek
        )
        .padding(.horizontal, JourneyLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
    .preferredColorScheme(.dark)
}
