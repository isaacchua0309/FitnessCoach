//
//  TodayLayout.swift
//  Fitness Coach
//
//  Forma — Shared spacing and card chrome for the Today screen.
//

import SwiftUI

enum TodayLayout {
    /// Space between major Today sections.
    static let zoneSpacing = FormaTokens.Spacing.xl
    /// Hero and goal connection within the mission block.
    static let statusZoneSpacing = FormaTokens.Spacing.sm
    /// Legacy alias — prefer `sectionSpacing` for the flat section stack.
    static let loggedZoneSpacing = FormaTokens.Spacing.md
    static let sectionSpacing = zoneSpacing
    /// Tighter stack inside a zone.
    static let planBlockSpacing = loggedZoneSpacing
    /// Label to card within a section.
    static let headerToCardSpacing = FormaTokens.Spacing.xs
    /// Tight label-to-content gap in the status zone.
    static let compactSpacing: CGFloat = 4
    /// Gap between hero value and supporting metrics.
    static let heroMetricsSpacing: CGFloat = 6
    /// Gap between mission block and next-best-action card.
    static let primaryActionZoneSpacing = FormaTokens.Spacing.sm
    static let itemSpacing = FormaFeatureLayout.itemSpacing
    static let horizontalPadding = FormaFeatureLayout.horizontalPadding
    static let actionIconColumnWidth: CGFloat = 22
    static let metricsProgressHeight: CGFloat = 5
    static let metricsProgressHeightPrimary: CGFloat = 6
    /// Vertical padding inside meal and list rows.
    static let cardRowVerticalPadding = FormaTokens.Spacing.sm
    /// Scroll padding below the last Today section (see `FormaMainTabLayout`).
    static let bottomScrollPadding = FormaFeatureLayout.scrollBottomPadding
    /// Tighter spacing for reinforcement sections at the bottom of Today.
    static let reinforcementSpacing = FormaTokens.Spacing.sm
}

struct TodaySectionLabel: View {
    let title: String

    var body: some View {
        FormaSectionLabel(title: title)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Softer section label for measurement rows (Targets).
struct TodayMutedSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(FormaTokens.Typography.caption.weight(.medium))
            .foregroundStyle(FormaTokens.Color.textTertiary)
            .textCase(.uppercase)
            .tracking(0.4)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Next Actions

struct TodayActionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FormaCardChrome.background(.accentLeading))
            .formaThemeReactive()
    }
}

// MARK: - Targets

struct TodayMetricsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FormaCardChrome.background(.surfaceSubtle))
            .formaThemeReactive()
    }
}

struct TodayMetricProgressBar: View {
    let progress: Double
    var height: CGFloat = TodayLayout.metricsProgressHeight
    var subdued: Bool = true
    var isOverTarget: Bool = false

    @Environment(\.formaColors) private var colors

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var fillColor: Color {
        if isOverTarget {
            return colors.destructive.opacity(subdued ? 0.8 : 1)
        }
        return colors.progress.opacity(subdued ? 0.6 : 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(colors.progressTrack)

                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(fillColor)
                    .frame(width: max(geometry.size.width * clampedProgress, clampedProgress > 0 ? 4 : 0))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
