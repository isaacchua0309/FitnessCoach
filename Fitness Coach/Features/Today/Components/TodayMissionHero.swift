//
//  TodayMissionHero.swift
//  Fitness Coach
//
//  Forma — Today's Mission hero: one dominant calorie number and supporting context.
//

import SwiftUI

struct TodayMissionHero: View {
    let mission: TodayMissionState
    let onLogMeal: () -> Void
    /// When true, hides the inline log-meal chip so Next Best Action stays the single dominant CTA.
    var suppressLogMealCTA: Bool = false
    var onViewed: (() -> Void)?

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var heroValueSize: CGFloat = 48

    var body: some View {
        let _ = themeManager.themeRevision
        return VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            SectionLabel(title: mission.sectionTitle)

            metricsBlock

            if mission.showsLogMealCTA, !suppressLogMealCTA {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                    FormaQuickActionChip(
                        title: FormaProductCopy.Today.Mission.logMealCTA,
                        action: onLogMeal,
                        accessibilityHint: FormaProductCopy.Today.mealsLogMealAccessibilityHint
                    )

                    Text(FormaProductCopy.Today.QuickActions.logMealMicrocopy)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, FormaTokens.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            onViewed?()
        }
        .todayLiveTheme()
    }

    private var metricsBlock: some View {
        VStack(alignment: .leading, spacing: TodayLayout.heroMetricsSpacing) {
            Text(mission.primaryValue)
                .font(.system(size: heroValueSize, weight: .bold, design: .rounded))
                .foregroundStyle(primaryValueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .allowsTightening(true)
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            if showsSupportingLines {
                supportingLinesBlock
            }

            nextStepBlock

            if !mission.statusLine.isEmpty {
                Text(mission.statusLine)
                    .font(FormaTokens.Typography.caption.weight(.medium))
                    .foregroundStyle(statusLineColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mission.accessibilityLabel)
    }

    private var showsSupportingLines: Bool {
        switch mission.primaryKind {
        case .targetReached:
            return !mission.proteinRemainingLine.isEmpty || !mission.waterRemainingLine.isEmpty
        case .remaining, .over, .missingTarget:
            return true
        }
    }

    private var showsNextStepLine: Bool {
        !mission.nextStepLine.isEmpty
    }

    private var supportingLinesBlock: some View {
        VStack(alignment: .leading, spacing: TodayLayout.compactSpacing) {
            if mission.primaryKind != .targetReached {
                supportingLine(mission.goalLine)
                supportingLine(mission.consumedLine)
            }
            supportingLine(mission.proteinRemainingLine)
            if !mission.waterRemainingLine.isEmpty {
                supportingLine(mission.waterRemainingLine)
            }
        }
    }

    @ViewBuilder
    private var nextStepBlock: some View {
        if showsNextStepLine {
            Text(mission.nextStepLine)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
                .padding(.top, FormaTokens.Spacing.xs)
        }
    }

    private func supportingLine(_ text: String) -> some View {
        Text(text)
            .font(FormaTokens.Typography.caption)
            .foregroundStyle(theme.tertiaryText)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var primaryValueColor: Color {
        switch mission.primaryKind {
        case .over:
            return theme.destructive
        case .targetReached:
            return theme.accent
        case .remaining, .missingTarget:
            return theme.primaryText
        }
    }

    private var statusLineColor: Color {
        switch mission.primaryKind {
        case .over:
            return theme.destructive.opacity(0.9)
        case .targetReached:
            return theme.accent
        case .remaining, .missingTarget:
            return theme.secondaryText.opacity(0.62)
        }
    }
}

#if DEBUG
#Preview("New profile") {
    TodayMissionHero(
        mission: TodayPreviewData.emptyDay.mission,
        onLogMeal: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Partial day") {
    TodayMissionHero(
        mission: TodayPreviewData.partialDay.mission,
        onLogMeal: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Over target") {
    TodayMissionHero(
        mission: TodayPreviewData.overTargetDay.mission,
        onLogMeal: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Large text") {
    TodayMissionHero(
        mission: TodayPreviewData.partialDay.mission,
        onLogMeal: {}
    )
    .padding()
    .dynamicTypeSize(.accessibility2)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
