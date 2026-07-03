//
//  TodayHealthIntelligenceSection.swift
//  Fitness Coach
//
//  Forma — Composes Today Health Intelligence cards into a single section stack.
//

import SwiftUI

struct TodayHealthIntelligenceSection: View {
    let state: TodayHealthIntelligenceSectionState
    var onNextBestAction: ((TodayHealthNextBestActionDestination) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.loggedZoneSpacing) {
            TodayRecoveryCard(
                state: state.recoveryCard,
                isLoading: state.isLoading
            )

            TodayDailyMissionCard(
                state: state.dailyMission,
                isLoading: state.isLoading
            )

            if state.nextBestAction.isVisible {
                TodayNextBestActionCard(
                    state: state.nextBestAction,
                    isLoading: state.isLoading,
                    onAction: nextBestActionHandler
                )
            }

            if let workoutCard = state.workoutCard {
                TodayHealthWorkoutCard(
                    state: workoutCard,
                    isLoading: state.isLoading
                )
            }

            if let adaptiveCard = state.adaptiveNutritionCard, adaptiveCard.isVisible {
                TodayAdaptiveNutritionCard(
                    state: adaptiveCard,
                    isLoading: state.isLoading
                )
            }

            if let fallbackMessage = state.fallbackMessage,
               shouldShowStandaloneFallback {
                fallbackBanner(message: fallbackMessage)
            }
        }
        .formaThemeReactive()
    }

    private var shouldShowStandaloneFallback: Bool {
        guard !state.isLoading else { return false }
        guard !state.nextBestAction.isVisible else { return false }
        return true
    }

    private var nextBestActionHandler: (() -> Void)? {
        guard let onNextBestAction else { return nil }
        let destination = state.nextBestAction.destination
        guard destination != .none else { return nil }
        return { onNextBestAction(destination) }
    }

    @ViewBuilder
    private func fallbackBanner(message: String) -> some View {
        FormaPlanCard {
            Text(message)
                .font(TodayHealthIntelligenceCardTypography.detail)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .padding(.vertical, FormaTokens.Spacing.xs)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

// MARK: - Previews

#Preview("Ready day") {
    ScrollView {
        TodayHealthIntelligenceSection(
            state: TodayHealthIntelligencePreviewData.readyDay,
            onNextBestAction: { _ in }
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Workout day") {
    ScrollView {
        TodayHealthIntelligenceSection(
            state: TodayHealthIntelligencePreviewData.workoutDay,
            onNextBestAction: { _ in }
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Low recovery day") {
    ScrollView {
        TodayHealthIntelligenceSection(
            state: TodayHealthIntelligencePreviewData.lowRecoveryDay,
            onNextBestAction: { _ in }
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("No health data") {
    ScrollView {
        TodayHealthIntelligenceSection(
            state: TodayHealthIntelligencePreviewData.noHealthData,
            onNextBestAction: { _ in }
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Loading") {
    ScrollView {
        TodayHealthIntelligenceSection(state: TodayHealthIntelligencePreviewData.loading)
            .padding(.horizontal, TodayLayout.horizontalPadding)
            .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Theme matrix — Blossom Pink") {
    ScrollView {
        TodayHealthIntelligenceSection(
            state: TodayHealthIntelligencePreviewData.workoutDay,
            onNextBestAction: { _ in }
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview(palette: .blossomPink)
}
