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
    var onWeeklyReviewSelected: ((WeeklyReviewDetailState) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.sectionSpacing) {
            if let connectCTA = state.connectHealthCTA {
                connectHealthCard(connectCTA)
            }

            if let weeklyReviewCard = state.weeklyReviewCard {
                weeklyReviewCardView(weeklyReviewCard)
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
        } else {
            WeeklyReviewCard(state: card, isLoading: state.isLoading)
                .accessibilityIdentifier("journey-weekly-review-card")
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
