//
//  TrainingInsightsEmptyConnectedView.swift
//  Fitness Coach
//
//  Forma — Connected Apple Health with no workouts yet (non-judgmental).
//

import SwiftUI

struct TrainingInsightsEmptyConnectedView: View {

    @ObservedObject var insightsStore: TrainingInsightsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TrainingLayout.sectionSpacing) {
                TrainingInsightsConnectedHeader()

                FormaEmptyStateCard(
                    title: FormaProductCopy.EmptyState.TrainingInsights.connectedEmptyTitle,
                    message: FormaProductCopy.EmptyState.TrainingInsights.connectedEmptyBody
                ) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(FormaTokens.Color.accent)
                }

                coachNoteCard

                manageConnectionLink
            }
            .padding(.horizontal, TrainingLayout.horizontalPadding)
            .padding(.top, FormaTokens.Spacing.sm)
            .padding(.bottom, TrainingLayout.scrollBottomPadding)
        }
        .formaScrollBottomInset()
    }

    private var coachNoteCard: some View {
        VStack(alignment: .leading, spacing: TrainingLayout.itemSpacing) {
            FormaSectionLabel(title: "Coach note")

            FormaPlanCard {
                Text(TrainingInsightsCoachNoteBuilder.note(weeklyWorkoutCount: 0))
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textLegal)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var manageConnectionLink: some View {
        NavigationLink {
            AppleHealthIntegrationView(insightsStore: insightsStore)
        } label: {
            FormaActionRow(
                title: TrainingIntegrationCopy.manageConnection,
                style: .linkAccent
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Apple Health integration settings")
    }
}

#Preview {
    NavigationStack {
        TrainingInsightsEmptyConnectedView(
            insightsStore: TrainingInsightsStore(
                integration: StubTrainingIntegrationProvider(refreshResult: .connected)
            )
        )
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
