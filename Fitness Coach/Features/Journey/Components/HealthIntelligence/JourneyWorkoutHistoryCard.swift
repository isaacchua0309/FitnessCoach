//
//  JourneyWorkoutHistoryCard.swift
//  Fitness Coach
//
//  Forma — Recent workout list for Journey Health Intelligence.
//

import SwiftUI

struct JourneyWorkoutHistoryCard: View {
    let state: JourneyWorkoutHistoryState
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            JourneySectionLabel(title: state.sectionTitle)

            JourneyHealthIntelligenceLoadingCard(isLoading: isLoading || state.phase == .loading) {
                JourneyCard(elevation: .quiet) {
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
        .accessibilityIdentifier("journey-hi-workout-history-card")
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
        ForEach(0..<3, id: \.self) { index in
            if index > 0 {
                FormaPlanRowDivider()
            }
            JourneyWorkoutHistoryRow(item: placeholderItem(index: index))
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
        if !state.groups.isEmpty {
            groupedContent
        } else {
            flatContent
        }
    }

    @ViewBuilder
    private var groupedContent: some View {
        ForEach(Array(state.groups.enumerated()), id: \.element.id) { index, group in
            if index > 0 {
                FormaPlanRowDivider()
            }

            VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
                Text(group.dateLabel)
                    .font(FormaTokens.Typography.caption2.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .accessibilityHidden(true)

                ForEach(Array(group.items.enumerated()), id: \.element.id) { itemIndex, item in
                    if itemIndex > 0 {
                        FormaPlanRowDivider()
                    }
                    JourneyWorkoutHistoryRow(item: item)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(group.accessibilityLabel)
        }
    }

    @ViewBuilder
    private var flatContent: some View {
        ForEach(Array(state.items.enumerated()), id: \.element.id) { index, item in
            if index > 0 {
                FormaPlanRowDivider()
            }
            JourneyWorkoutHistoryRow(item: item, showsDateLabel: true)
        }
    }

    private func placeholderItem(index: Int) -> JourneyWorkoutHistoryItemState {
        JourneyWorkoutHistoryItemState(
            id: "placeholder-\(index)",
            date: Date(),
            dateLabel: "—",
            workoutTitle: "Workout title",
            durationLabel: "45 min",
            caloriesLabel: "300 kcal est.",
            demandLabel: "High demand",
            intensityLabel: nil,
            shortExplanation: nil,
            accessibilityLabel: "Loading"
        )
    }
}

// MARK: - Previews

#Preview("Loaded") {
    JourneyWorkoutHistoryCard(
        state: JourneyHealthIntelligencePreviewData.strongWeek.workoutHistory
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Connected — no workouts") {
    JourneyWorkoutHistoryCard(
        state: JourneyHealthIntelligencePreviewData.connectedNoWorkouts.workoutHistory
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Loading") {
    JourneyWorkoutHistoryCard(
        state: JourneyHealthIntelligencePreviewData.loading.workoutHistory,
        isLoading: true
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Theme — Emerald Green") {
    JourneyWorkoutHistoryCard(
        state: JourneyHealthIntelligencePreviewData.strongWeek.workoutHistory
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview(palette: .emeraldGreen)
}
