//
//  ThisWeekCard.swift
//  Fitness Coach
//
//  Forma — Unified Journey weekly summary (replaces duplicate weekly review sections).
//

import SwiftUI

struct ThisWeekSection: View {
    let state: UnifiedWeeklyReviewState
    var summary: WeeklyProgressSummary
    var weeklyProgressAnalyticsCoordinator: WeeklyProgressAnalyticsCoordinator?
    var freshnessInput: WeeklyProgressFreshnessInput?
    var onPrimaryCTA: ((WeeklyProgressCTA) -> Void)?
    var onOpenWeeklyReviewDetail: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            SectionLabel(title: state.weekTitle)

            ThisWeekCard(
                state: state,
                summary: summary,
                weeklyProgressAnalyticsCoordinator: weeklyProgressAnalyticsCoordinator,
                freshnessInput: freshnessInput,
                onPrimaryCTA: onPrimaryCTA,
                onOpenWeeklyReviewDetail: onOpenWeeklyReviewDetail
            )
        }
        .accessibilityIdentifier("journey-this-week-section")
    }
}

struct ThisWeekCard: View {
    let state: UnifiedWeeklyReviewState
    var summary: WeeklyProgressSummary
    var weeklyProgressAnalyticsCoordinator: WeeklyProgressAnalyticsCoordinator?
    var freshnessInput: WeeklyProgressFreshnessInput?
    var onPrimaryCTA: ((WeeklyProgressCTA) -> Void)?
    var onOpenWeeklyReviewDetail: (() -> Void)?

    var body: some View {
        JourneyCard(elevation: .featured) {
            VStack(alignment: .leading, spacing: WeeklyProgressCardSupport.contentSpacing) {
                if !state.dateRangeText.isEmpty {
                    Text(state.dateRangeText)
                        .font(WeeklyReviewTypography.eyebrow)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                }

                Text(state.cardStateTitle)
                    .font(WeeklyReviewTypography.cardTitle)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(state.cardSummary)
                    .font(WeeklyReviewTypography.body)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !state.compactStats.isEmpty {
                    compactStatsRow
                }

                if state.isInsufficientData, let checklist = state.unlockChecklist {
                    JourneyUnlockCard(checklist: checklist, style: .compact)
                }

                HStack {
                    if !state.confidenceLabel.isEmpty {
                        WeeklyReviewConfidenceBadge(
                            label: state.confidenceLabel,
                            isLimited: state.confidenceLabel
                                == FormaProductCopy.Journey.WeeklyConfidence.building
                        )
                    }
                    Spacer(minLength: 0)
                }

                if let primaryCTA = state.primaryCTA,
                   !state.suppressDuplicateUnlockCTA,
                   let onPrimaryCTA {
                    WeeklyProgressCTAButton(cta: primaryCTA, prominence: .primary) {
                        onPrimaryCTA(primaryCTA)
                    }
                    .padding(.top, JourneyLayout.compactSpacing)
                }

                if let message = state.freshness?.cardMessage {
                    Text(message)
                        .font(FormaTokens.Typography.caption2)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, FormaTokens.Spacing.xs)
                        .accessibilityLabel(message)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenWeeklyReviewDetail?()
        }
        .onAppear {
            weeklyProgressAnalyticsCoordinator?.logCardViewed(
                summary: summary,
                freshnessInput: freshnessInput
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(onOpenWeeklyReviewDetail == nil ? [] : .isButton)
        .formaThemeReactive()
    }

    private var compactStatsRow: some View {
        CoachFlowLayout(
            horizontalSpacing: FormaTokens.Spacing.xs,
            verticalSpacing: FormaTokens.Spacing.xs
        ) {
            ForEach(state.compactStats) { stat in
                Text(stat.label)
                    .font(FormaTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .padding(.horizontal, FormaTokens.Spacing.sm)
                    .padding(.vertical, FormaTokens.Spacing.xs)
                    .background(
                        Capsule(style: .continuous)
                            .fill(FormaTokens.Color.surfaceSubtle)
                    )
                    .accessibilityLabel(stat.label)
            }
        }
        .padding(.top, FormaTokens.Spacing.xs)
    }

    private var accessibilitySummary: String {
        var parts = [
            state.weekTitle,
            state.dateRangeText,
            state.cardStateTitle,
            state.cardSummary,
            state.compactStats.map(\.label).joined(separator: ", "),
            state.confidenceAccessibilityLabel
        ]
        if let primary = state.primaryCTA {
            parts.append(primary.accessibilityLabel)
        }
        if let freshness = state.freshness?.accessibilityLabel, !freshness.isEmpty {
            parts.append(freshness)
        }
        return parts.filter { !$0.isEmpty }.joined(separator: ". ")
    }
}

#if DEBUG
#Preview("Getting started") {
    let dashboard = JourneyPreviewData.brandNewUser
    let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

    ThisWeekSection(
        state: unified,
        summary: dashboard.weeklyProgressSummary
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Strong momentum") {
    let dashboard = JourneyPreviewData.strongMomentum
    let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

    ThisWeekSection(
        state: unified,
        summary: dashboard.weeklyProgressSummary
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
