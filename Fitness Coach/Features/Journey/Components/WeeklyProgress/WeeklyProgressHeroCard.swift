//
//  WeeklyProgressHeroCard.swift
//  Fitness Coach
//
//  Forma — Primary Journey weekly progress hero card (week-2 ritual).
//

import SwiftUI

enum WeeklyProgressCardSupport {
    static let contentSpacing = FormaTokens.Spacing.sm
    static let blockSpacing = FormaTokens.Spacing.xs
    static let blockPadding = FormaTokens.Spacing.sm
    static let maxVisibleHabits = 3

    static let blockTitleFont = JourneyTypography.cardHeadline
    static let metricFont = JourneyTypography.metricValue
    static let metricUnitFont = FormaTokens.Typography.caption.weight(.medium)
    static let supportingFont = JourneyTypography.cardSupporting
}

struct WeeklyProgressHeroSection: View {
    let state: UnifiedWeeklyReviewState
    var foodLoggedDays: Int = 0
    var totalDays: Int = 7
    var onPrimaryCTA: ((WeeklyProgressCTA) -> Void)?
    var onSecondaryCTA: ((WeeklyProgressCTA) -> Void)?
    var onOpenWeeklyReviewDetail: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            JourneySectionLabel(title: state.weekTitle)

            WeeklyProgressHeroCard(
                state: state,
                foodLoggedDays: foodLoggedDays,
                totalDays: totalDays,
                onPrimaryCTA: onPrimaryCTA,
                onSecondaryCTA: onSecondaryCTA,
                onOpenWeeklyReviewDetail: onOpenWeeklyReviewDetail
            )
        }
        .accessibilityIdentifier("journey-weekly-progress-section")
    }
}

struct WeeklyProgressHeroCard: View {
    let state: UnifiedWeeklyReviewState
    var foodLoggedDays: Int = 0
    var totalDays: Int = 7
    var onPrimaryCTA: ((WeeklyProgressCTA) -> Void)?
    var onSecondaryCTA: ((WeeklyProgressCTA) -> Void)?
    var onOpenWeeklyReviewDetail: (() -> Void)?

    private var topHabitRows: [JourneyWeeklyHabitRowState] {
        Array(state.habitRows.prefix(WeeklyProgressCardSupport.maxVisibleHabits))
    }

    var body: some View {
        JourneyCard(elevation: .featured) {
            VStack(alignment: .leading, spacing: WeeklyProgressCardSupport.contentSpacing) {
                headerRow
                headlineBlock
                summaryBlock

                if state.isInsufficientData {
                    insufficientDataBlock
                }

                if let maintenanceBlock = state.maintenanceBlock {
                    WeeklyMaintenanceBlockView(state: maintenanceBlock)
                }

                if let planBlock = state.planRecommendationBlock {
                    WeeklyPlanRecommendationBlockView(state: planBlock)
                }

                if let weightBlock = state.weightTrendBlock {
                    WeeklyWeightTrendBlockView(state: weightBlock)
                }

                if !topHabitRows.isEmpty {
                    habitRowsBlock
                }

                if !state.caveats.isEmpty, !state.isInsufficientData {
                    caveatsBlock
                }

                ctaBlock
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenWeeklyReviewDetail?()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(onOpenWeeklyReviewDetail == nil ? [] : .isButton)
        .formaThemeReactive()
    }

  private var headerRow: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            if !state.dateRangeText.isEmpty {
                Text(state.dateRangeText)
                    .font(WeeklyReviewTypography.eyebrow)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.4)
            }

            Spacer(minLength: 0)

            if !state.confidenceLabel.isEmpty {
                WeeklyReviewConfidenceBadge(
                    label: state.confidenceLabel,
                    isLimited: state.isInsufficientData
                        || state.confidenceLabel == FormaProductCopy.WeeklyReviewPresentation.confidenceLow
                        || state.confidenceLabel == FormaProductCopy.WeeklyReviewPresentation.notEnoughDataTitle
                )
            }
        }
    }

    private var headlineBlock: some View {
        Text(state.headline)
            .font(WeeklyReviewTypography.cardTitle)
            .foregroundStyle(FormaTokens.Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var summaryBlock: some View {
        Text(state.summary)
            .font(WeeklyReviewTypography.body)
            .foregroundStyle(FormaTokens.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var insufficientDataBlock: some View {
        VStack(alignment: .leading, spacing: WeeklyProgressCardSupport.blockSpacing) {
            if foodLoggedDays > 0 {
                Text(FormaProductCopy.WeeklyReviewPresentation.dayCountValue(foodLoggedDays, total: totalDays))
                    .font(WeeklyProgressCardSupport.supportingFont.weight(.medium))
                    .foregroundStyle(FormaTokens.Theme.primary)
            }

            Text(insufficientDataGuidanceTitle)
                .font(WeeklyProgressCardSupport.blockTitleFont)
                .foregroundStyle(FormaTokens.Color.textPrimary)

            ForEach(insufficientDataGuidance, id: \.self) { item in
                HStack(alignment: .top, spacing: FormaTokens.Spacing.xs) {
                    Text("•")
                        .font(WeeklyProgressCardSupport.supportingFont)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                    Text(item)
                        .font(WeeklyProgressCardSupport.supportingFont)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(WeeklyProgressCardSupport.blockPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FormaCardChrome.background(.surfaceSubtle))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(insufficientDataAccessibilityLabel)
    }

    private var habitRowsBlock: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
            WeeklyReviewSectionHeader(title: FormaProductCopy.Journey.WeeklyReview.sectionTitle)

            ForEach(Array(topHabitRows.enumerated()), id: \.element.id) { index, habit in
                if index > 0 {
                    FormaPlanRowDivider()
                }
                WeeklyProgressHabitRowView(habit: habit)
            }
        }
    }

    private var caveatsBlock: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
            ForEach(state.caveats, id: \.self) { caveat in
                Text(caveat)
                    .font(FormaTokens.Typography.caption2)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var ctaBlock: some View {
        if let primaryCTA = state.primaryCTA, let onPrimaryCTA {
            WeeklyProgressCTAButton(cta: primaryCTA, prominence: .primary) {
                onPrimaryCTA(primaryCTA)
            }
            .padding(.top, JourneyLayout.compactSpacing)
        }

        if let secondaryCTA = state.secondaryCTA, let onSecondaryCTA {
            WeeklyProgressCTAButton(cta: secondaryCTA, prominence: .secondary) {
                onSecondaryCTA(secondaryCTA)
            }
        }
    }

    private var insufficientDataGuidanceTitle: String {
        FormaProductCopy.WeeklyReviewPresentation.notEnoughDataRequirements
    }

    private var insufficientDataGuidance: [String] {
        let guidance = state.caveats.filter { !$0.isEmpty }
        if guidance.isEmpty {
            return [state.confidenceAccessibilityLabel]
        }
        return guidance
    }

    private var insufficientDataAccessibilityLabel: String {
        [insufficientDataGuidanceTitle]
            .appending(insufficientDataGuidance)
            .joined(separator: ". ")
    }

    private var accessibilitySummary: String {
        var parts = [
            state.weekTitle,
            state.dateRangeText,
            state.headline,
            state.summary,
            state.confidenceAccessibilityLabel
        ]

        if let maintenance = state.maintenanceBlock {
            parts.append(maintenance.accessibilityLabel)
        }
        if let plan = state.planRecommendationBlock {
            parts.append(plan.accessibilityLabel)
        }
        if let weight = state.weightTrendBlock {
            parts.append(weight.accessibilityLabel)
        }
        if let primary = state.primaryCTA {
            parts.append(primary.accessibilityLabel)
        }

        return parts.filter { !$0.isEmpty }.joined(separator: ". ")
    }
}

// MARK: - Habit row

struct WeeklyProgressHabitRowView: View {
    let habit: JourneyWeeklyHabitRowState

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                Text(habit.title)
                    .font(JourneyTypography.metricLabel)
                    .foregroundStyle(FormaTokens.Color.textPrimary)

                Spacer(minLength: FormaTokens.Spacing.xs)

                Text(habit.weeklyCountLabel)
                    .font(JourneyTypography.cardSupporting.weight(.medium))
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .multilineTextAlignment(.trailing)
            }

            if habit.showsDayProgress {
                JourneyDayDotRow(cells: habit.dayCells)
            }

            if let streakLabel = habit.streakLabel {
                Text(streakLabel)
                    .font(FormaTokens.Typography.caption2.weight(.medium))
                    .foregroundStyle(FormaTokens.Theme.primary)
            } else if let supportiveCopy = habit.supportiveCopy {
                Text(supportiveCopy)
                    .font(FormaTokens.Typography.caption2)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, JourneyLayout.compactSpacing)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - CTA button

enum WeeklyProgressCTAProminence {
    case primary
    case secondary
}

struct WeeklyProgressCTAButton: View {
    let cta: WeeklyProgressCTA
    var prominence: WeeklyProgressCTAProminence = .primary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
                HStack(spacing: FormaTokens.Spacing.xs) {
                    Text(cta.title)
                        .font(prominence == .primary ? JourneyTypography.cardHeadline : JourneyTypography.cardSupporting.weight(.semibold))
                        .foregroundStyle(foregroundColor)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: FormaTokens.Spacing.xs)

                    Image(systemName: "chevron.right")
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(foregroundColor.opacity(0.75))
                }

                if let subtitle = cta.subtitle {
                    Text(subtitle)
                        .font(FormaTokens.Typography.caption2)
                        .foregroundStyle(subtitleColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .leading)
            .padding(.horizontal, prominence == .primary ? FormaTokens.Spacing.sm : 0)
            .padding(.vertical, prominence == .primary ? FormaTokens.Spacing.sm : JourneyLayout.compactSpacing)
            .background {
                if prominence == .primary {
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                        .fill(FormaTokens.Theme.softBackground.opacity(0.72))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cta.accessibilityLabel)
    }

    private var foregroundColor: Color {
        FormaTokens.Theme.primary
    }

    private var subtitleColor: Color {
        FormaTokens.Color.textSecondary
    }
}

// MARK: - CTA routing

enum WeeklyProgressCTAHandler {

    static func perform(
        _ cta: WeeklyProgressCTA,
        onOpenToday: (() -> Void)?,
        onOpenPlan: (() -> Void)?,
        onOpenPlanForWeeklyReview: (() -> Void)? = nil,
        onOpenCoach: ((String?) -> Void)? = nil
    ) {
        switch cta.kind {
        case .reviewPlan:
            if let onOpenPlanForWeeklyReview {
                onOpenPlanForWeeklyReview()
            } else {
                onOpenPlan?()
            }
        case .holdSteady, .connectAppleHealth:
            onOpenPlan?()
        case .keepLogging, .improveLoggingConsistency:
            onOpenToday?()
        case .logWeight:
            if let onOpenCoach {
                onOpenCoach(TodayCoachPrompt.logWeight)
            } else {
                onOpenToday?()
            }
        case .logFood:
            if let onOpenCoach {
                onOpenCoach(TodayCoachPrompt.logMeal())
            } else {
                onOpenToday?()
            }
        case .focusProtein:
            if let onOpenCoach {
                onOpenCoach(TodayCoachPrompt.logProtein)
            } else {
                onOpenToday?()
            }
        case .focusWater:
            if let onOpenCoach {
                onOpenCoach(TodayCoachPrompt.logWater)
            } else {
                onOpenToday?()
            }
        }
    }
}

#if DEBUG
#Preview("Strong momentum") {
    let dashboard = JourneyPreviewData.strongMomentum
    let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

    WeeklyProgressHeroSection(
        state: unified,
        foodLoggedDays: dashboard.weeklyProgressSummary.foodLoggedDays,
        totalDays: dashboard.weeklyProgressSummary.totalDays
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Insufficient data") {
    let dashboard = JourneyPreviewData.brandNewUser
    let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

    WeeklyProgressHeroSection(
        state: unified,
        foodLoggedDays: dashboard.weeklyProgressSummary.foodLoggedDays,
        totalDays: dashboard.weeklyProgressSummary.totalDays
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Dark mode") {
    let dashboard = JourneyPreviewData.strongMomentum
    let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

    WeeklyProgressHeroSection(state: unified)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
        .preferredColorScheme(.dark)
}
#endif
