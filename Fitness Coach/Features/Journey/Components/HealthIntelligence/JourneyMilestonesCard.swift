//
//  JourneyMilestonesCard.swift
//  Fitness Coach
//
//  Forma — Health milestone chips for Journey Health Intelligence.
//

import SwiftUI

struct JourneyMilestonesCard: View {
    let state: JourneyHealthMilestonesState
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            SectionLabel(title: state.sectionTitle)

            JourneyHealthIntelligenceLoadingCard(isLoading: isLoading || state.phase == .loading) {
                JourneyCard(elevation: .standard) {
                    VStack(alignment: .leading, spacing: JourneyHealthIntelligenceCardSupport.cardContentSpacing) {
                        cardHeadline

                        switch state.phase {
                        case .loading:
                            loadingContent
                        case .empty:
                            emptyContent
                        case .error:
                            errorContent
                        case .loaded:
                            loadedContent
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityIdentifier("journey-hi-milestones-card")
        .formaThemeReactive()
    }

    @ViewBuilder
    private var cardHeadline: some View {
        Text(state.headline)
            .font(JourneyTypography.cardSupporting.weight(.semibold))
            .foregroundStyle(FormaTokens.Color.textTertiary)
            .textCase(.uppercase)
            .tracking(0.4)
            .accessibilityHidden(state.phase == .loading)
    }

    @ViewBuilder
    private var loadingContent: some View {
        CoachFlowLayout(
            horizontalSpacing: FormaTokens.Spacing.xs,
            verticalSpacing: FormaTokens.Spacing.xs
        ) {
            ForEach(0..<3, id: \.self) { index in
                placeholderChip(index: index)
            }
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        if let emptyMessage = state.emptyMessage {
            JourneyHealthIntelligencePhaseMessage(message: emptyMessage)
        }
    }

    @ViewBuilder
    private var errorContent: some View {
        if let errorMessage = state.errorMessage {
            JourneyHealthIntelligencePhaseMessage(message: errorMessage, tone: .caution)
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        CoachFlowLayout(
            horizontalSpacing: FormaTokens.Spacing.xs,
            verticalSpacing: FormaTokens.Spacing.xs
        ) {
            ForEach(state.items) { milestone in
                JourneyHealthMilestoneChip(milestone: milestone)
            }
        }
    }

    private func placeholderChip(index: Int) -> some View {
        JourneyHealthMilestoneChip(
            milestone: JourneyHealthMilestoneState(
                id: "placeholder-\(index)",
                kind: .weeklyWin,
                title: "Milestone title",
                detail: "",
                status: .achieved,
                statusLabel: "Achieved",
                progressLabel: nil,
                accessibilityLabel: "Loading"
            )
        )
    }
}

// MARK: - Previews

#Preview("Loaded") {
    JourneyMilestonesCard(
        state: JourneyHealthIntelligencePreviewData.strongWeek.milestones
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Empty") {
    JourneyMilestonesCard(
        state: JourneyHealthIntelligencePreviewData.unavailable.milestones
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Loading") {
    JourneyMilestonesCard(
        state: JourneyHealthIntelligencePreviewData.loading.milestones,
        isLoading: true
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Theme — Blossom Pink") {
    JourneyMilestonesCard(
        state: JourneyHealthIntelligencePreviewData.strongWeek.milestones
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview(palette: .blossomPink)
}
