//
//  JourneyHighlightsSection.swift
//  Fitness Coach
//
//  Forma — Rewarding health milestone chips for the Journey dashboard.
//

import SwiftUI

struct JourneyHighlightsSection: View {
    let state: JourneyHealthMilestonesState
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            JourneySectionLabel(title: FormaProductCopy.Journey.Dashboard.Highlights.sectionTitle)

            JourneyHealthIntelligenceLoadingCard(isLoading: isLoading || state.phase == .loading) {
                JourneyCard(elevation: .standard) {
                    switch state.phase {
                    case .loading:
                        loadingContent
                    case .empty, .error:
                        EmptyView()
                    case .loaded:
                        loadedContent
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityIdentifier("journey-highlights-section")
        .formaThemeReactive()
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
                title: "Milestone",
                detail: "",
                status: .achieved,
                statusLabel: "Achieved",
                progressLabel: nil,
                accessibilityLabel: "Loading"
            )
        )
    }
}

#if DEBUG
#Preview("Highlights") {
    JourneyHighlightsSection(
        state: JourneyHealthIntelligencePreviewData.strongWeek.milestones
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
