//
//  JourneyHealthIntelligenceSection.swift
//  Fitness Coach
//
//  Forma — Composes Journey Health Intelligence cards into a section stack.
//

import SwiftUI

struct JourneyHealthIntelligenceSection: View {
    let state: JourneyHealthIntelligenceSectionState
    var healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator?
    var onConnectHealth: (() -> Void)?
    var onWeeklyReviewSelected: ((WeeklyReviewDetailState) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.sectionSpacing) {
            if let staleDataLabel = state.staleDataLabel {
                journeyInfoBanner(label: staleDataLabel)
            }

            if let connectCTA = state.connectHealthCTA {
                connectHealthCard(connectCTA)
            }

            if let partialSignalsNote = state.partialSignalsNote {
                journeyInfoBanner(label: partialSignalsNote)
            }

            if let weeklyReviewCard = state.weeklyReviewCard {
                weeklyReviewCardView(weeklyReviewCard)
            }

            JourneyRecoveryTimelineCard(
                state: state.recoveryTimeline,
                isLoading: state.isLoading,
                referenceDay: referenceDay
            )
            .onAppear {
                guard !state.isLoading, state.recoveryTimeline.phase == .loaded else { return }
                healthIntelligenceAnalyticsCoordinator?.logJourneyRecoveryTimelineViewed()
            }

            JourneyWorkoutHistoryCard(
                state: state.workoutHistory,
                isLoading: state.isLoading
            )
            .onAppear {
                guard !state.isLoading, state.workoutHistory.phase == .loaded else { return }
                healthIntelligenceAnalyticsCoordinator?.logJourneyWorkoutHistoryViewed()
            }

            JourneyMilestonesCard(
                state: state.milestones,
                isLoading: state.isLoading
            )

            JourneyHealthProgressCard(
                state: state.progress,
                isLoading: state.isLoading
            )

            if let fallbackMessage = state.fallbackMessage,
               state.connectHealthCTA == nil {
                journeyInfoBanner(label: fallbackMessage)
            }
        }
        .accessibilityIdentifier("journey-health-intelligence-section")
        .formaThemeReactive()
    }

    private var referenceDay: Date? {
        state.recoveryTimeline.days.last?.date
    }

    @ViewBuilder
    private func weeklyReviewCardView(_ card: WeeklyReviewCardState) -> some View {
        if card.phase == .loaded,
           let detail = state.weeklyReviewDetail,
           let onWeeklyReviewSelected {
            Button {
                onWeeklyReviewSelected(detail)
            } label: {
                WeeklyReviewCard(state: card, isLoading: state.isLoading)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens weekly review report")
            .accessibilityIdentifier("journey-weekly-review-card")
            .onAppear {
                guard !state.isLoading, card.phase == .loaded else { return }
                healthIntelligenceAnalyticsCoordinator?.logWeeklyReviewCardViewed()
            }
        } else {
            WeeklyReviewCard(state: card, isLoading: state.isLoading)
                .accessibilityIdentifier("journey-weekly-review-card")
                .onAppear {
                    guard !state.isLoading, card.phase == .loaded else { return }
                    healthIntelligenceAnalyticsCoordinator?.logWeeklyReviewCardViewed()
                }
        }
    }

    @ViewBuilder
    private func connectHealthCard(_ cta: JourneyHealthConnectCTAState) -> some View {
        JourneyCard(elevation: .quiet) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(cta.title)
                    .font(JourneyTypography.cardHeadline)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)

                Text(cta.message)
                    .font(JourneyTypography.cardSupporting)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .healthIntelligenceMultilineText()

                if let onConnectHealth {
                    Button(action: onConnectHealth) {
                        Text(cta.ctaTitle)
                            .font(FormaTokens.Typography.caption.weight(.semibold))
                            .foregroundStyle(FormaTokens.Theme.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, JourneyLayout.compactSpacing)
                    .accessibilityLabel(cta.ctaTitle)
                } else {
                    Text(cta.ctaTitle)
                        .font(JourneyTypography.cardHeadline)
                        .foregroundStyle(FormaTokens.Theme.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .padding(.top, JourneyLayout.compactSpacing)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cta.accessibilityLabel)
        .accessibilityIdentifier("journey-hi-connect-health-card")
    }

    @ViewBuilder
    private func journeyInfoBanner(label: String) -> some View {
        JourneyCard(elevation: .quiet) {
            Text(label)
                .font(JourneyTypography.cardSupporting)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .healthIntelligenceMultilineText()
        }
        .accessibilityIdentifier("journey-hi-fallback-banner")
    }
}

// MARK: - Previews

#Preview("Strong week") {
    ScrollView {
        JourneyHealthIntelligenceSection(
            state: JourneyHealthIntelligencePreviewData.strongWeek,
            onWeeklyReviewSelected: { _ in }
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
            state: JourneyHealthIntelligencePreviewData.strongWeek,
            onWeeklyReviewSelected: { _ in }
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
            state: JourneyHealthIntelligencePreviewData.strongWeek,
            onWeeklyReviewSelected: { _ in }
        )
        .padding(.horizontal, JourneyLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
    .preferredColorScheme(.dark)
}

#Preview("Partial permission") {
    ScrollView {
        JourneyHealthIntelligenceSection(
            state: JourneyHealthIntelligencePreviewData.partialPermission,
            onConnectHealth: {}
        )
        .padding(.horizontal, JourneyLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Sync failed — cached data") {
    ScrollView {
        JourneyHealthIntelligenceSection(
            state: JourneyHealthIntelligencePreviewData.syncFailedWithCache,
            onWeeklyReviewSelected: { _ in }
        )
        .padding(.horizontal, JourneyLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Building weekly review") {
    ScrollView {
        JourneyHealthIntelligenceSection(
            state: JourneyHealthIntelligencePreviewData.buildingWeeklyReview
        )
        .padding(.horizontal, JourneyLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Accessibility — Large Text") {
    ScrollView {
        JourneyHealthIntelligenceSection(
            state: JourneyHealthIntelligencePreviewData.strongWeek,
            onWeeklyReviewSelected: { _ in }
        )
        .padding(.horizontal, JourneyLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
    .dynamicTypeSize(.accessibility2)
}
