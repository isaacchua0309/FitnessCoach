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

    @ScaledMetric(relativeTo: .largeTitle) private var heroValueSize: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: mission.sectionTitle)

            metricsBlock

            if mission.showsLogMealCTA, !suppressLogMealCTA {
                FormaQuickActionChip(
                    title: FormaProductCopy.Today.Mission.logMealCTA,
                    action: onLogMeal,
                    style: .secondary,
                    accessibilityHint: FormaProductCopy.Today.mealsLogMealAccessibilityHint
                )
                .padding(.top, TodayLayout.compactSpacing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            onViewed?()
        }
    }

    private var metricsBlock: some View {
        VStack(alignment: .leading, spacing: TodayLayout.heroMetricsSpacing) {
            Text(mission.primaryValue)
                .font(.system(size: heroValueSize, weight: .bold, design: .rounded))
                .foregroundStyle(primaryValueColor)
                .minimumScaleFactor(0.65)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if showsSupportingLines {
                supportingLinesBlock
            }

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
            return !mission.proteinRemainingLine.isEmpty
        case .remaining, .over, .missingTarget:
            return true
        }
    }

    private var supportingLinesBlock: some View {
        VStack(alignment: .leading, spacing: TodayLayout.compactSpacing) {
            if mission.primaryKind != .targetReached {
                supportingLine(mission.goalLine)
                supportingLine(mission.consumedLine)
            }
            supportingLine(mission.proteinRemainingLine)
        }
    }

    private func supportingLine(_ text: String) -> some View {
        Text(text)
            .font(FormaTokens.Typography.caption)
            .foregroundStyle(FormaTokens.Color.textTertiary)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var primaryValueColor: Color {
        switch mission.primaryKind {
        case .over:
            return FormaTokens.Color.destructive
        case .targetReached:
            return FormaTokens.Theme.primary
        case .remaining, .missingTarget:
            return FormaTokens.Color.textPrimary
        }
    }

    private var statusLineColor: Color {
        switch mission.primaryKind {
        case .over:
            return FormaTokens.Color.destructive.opacity(0.9)
        case .targetReached:
            return FormaTokens.Theme.primary
        case .remaining, .missingTarget:
            return FormaTokens.Color.textLegal
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
