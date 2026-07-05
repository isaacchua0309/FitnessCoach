//
//  TodayHealthIntelligenceSection.swift
//  Fitness Coach
//
//  Forma — Composes Today Health Intelligence cards into a single section stack.
//

import SwiftUI

struct TodayHealthIntelligenceSection: View {
    let state: TodayHealthIntelligenceSectionState
    var healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator?
    var onNextBestAction: ((TodayHealthNextBestActionDestination) -> Void)?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.loggedZoneSpacing) {
            if let staleDataLabel = state.staleDataLabel {
                staleDataBanner(label: staleDataLabel)
            }

            TodayRecoveryCard(
                state: state.recoveryCard,
                isLoading: state.isLoading
            )
            .onAppear {
                guard !state.isLoading else { return }
                healthIntelligenceAnalyticsCoordinator?.logTodayRecoveryCardViewed()
            }

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
        .accessibilityIdentifier("today-health-intelligence-section")
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
                .foregroundStyle(fallbackForegroundColor)
                .healthIntelligenceMultilineText()
                .healthIntelligenceCardInnerPadding()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityIdentifier("today-hi-fallback-banner")
    }

    @ViewBuilder
    private func staleDataBanner(label: String) -> some View {
        HStack(spacing: FormaTokens.Spacing.xs) {
            Image(systemName: "clock.arrow.circlepath")
                .font(FormaTokens.Typography.caption2)
                .foregroundStyle(theme.tertiaryText)
                .accessibilityHidden(true)

            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(theme.tertiaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityIdentifier("today-hi-stale-label")
    }

    private var fallbackForegroundColor: Color {
        switch state.uiState?.severity {
        case .error:
            return theme.warning
        case .warning:
            return theme.secondaryText
        case .info, .none:
            return theme.secondaryText
        }
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

#Preview("Partial permission") {
    ScrollView {
        TodayHealthIntelligenceSection(
            state: TodayHealthIntelligencePreviewData.partialPermission,
            onNextBestAction: { _ in }
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("No permission") {
    ScrollView {
        TodayHealthIntelligenceSection(
            state: TodayHealthIntelligencePreviewData.noPermission,
            onNextBestAction: { _ in }
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("No sleep or heart") {
    ScrollView {
        TodayHealthIntelligenceSection(
            state: TodayHealthIntelligencePreviewData.noSleepOrHeart,
            onNextBestAction: { _ in }
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Sync failed with cache") {
    ScrollView {
        TodayHealthIntelligenceSection(
            state: TodayHealthIntelligencePreviewData.syncFailed,
            onNextBestAction: { _ in }
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("No workout history") {
    ScrollView {
        TodayHealthIntelligenceSection(
            state: TodayHealthIntelligencePreviewData.noWorkoutHistory,
            onNextBestAction: { _ in }
        )
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

#Preview("Accessibility — Large Text") {
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
    .dynamicTypeSize(.accessibility2)
}
