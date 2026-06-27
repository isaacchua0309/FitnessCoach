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

                FitPilotPlanCard {
                    VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(FormaTokens.Color.accent)

                        Text(TrainingIntegrationCopy.connectedEmptyTitle)
                            .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                            .foregroundStyle(FormaTokens.Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(TrainingIntegrationCopy.connectedEmptyMessage)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.textLegal)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                coachNoteCard

                manageConnectionLink
            }
            .padding(.horizontal, TrainingLayout.horizontalPadding)
            .padding(.top, FormaTokens.Spacing.sm)
            .padding(.bottom, TrainingLayout.scrollBottomPadding)
        }
        .fitPilotScrollBottomInset()
    }

    private var coachNoteCard: some View {
        VStack(alignment: .leading, spacing: TrainingLayout.itemSpacing) {
            TrainingSectionLabel(title: "Coach note")

            FitPilotPlanCard {
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
            HStack(spacing: FormaTokens.Spacing.sm) {
                Text(TrainingIntegrationCopy.manageConnection)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.accent)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
            .frame(minHeight: FitPilotScreenStyle.rowMinHeight, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    .preferredColorScheme(.dark)
}
