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
    static let headerToCardSpacing = FormaMainTabLayout.sectionContentSpacing
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
    /// Tighter spacing for reinforcement sections at the bottom of Today.
    static let reinforcementSpacing = FormaTokens.Spacing.sm
}

// MARK: - Live theme observation

/// Establishes SwiftUI dependencies on the shared theme store and semantic tokens so
/// Today cards repaint immediately when palette or appearance changes.
private struct TodayLiveThemeModifier: ViewModifier {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        let _ = themeManager.themeRevision
        let _ = theme.accent
        let _ = theme.accentLine
        return content
    }
}

extension View {
    func todayLiveTheme() -> some View {
        modifier(TodayLiveThemeModifier())
    }
}

// MARK: - Next Actions

struct TodayActionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        MainTabCard(style: .accentLeading, compact: true) {
            content
        }
        .todayLiveTheme()
    }
}

// MARK: - Targets

struct TodayMetricsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        MainTabCard(style: .surfaceSubtle, compact: true) {
            content
        }
        .todayLiveTheme()
    }
}

struct TodayMetricProgressBar: View {
    let progress: Double
    var height: CGFloat = TodayLayout.metricsProgressHeight
    var subdued: Bool = true
    var isOverTarget: Bool = false

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var fillColor: Color {
        if isOverTarget {
            return theme.destructive.opacity(subdued ? 0.8 : 1)
        }
        return theme.progressFill.opacity(subdued ? 0.6 : 1)
    }

    var body: some View {
        let _ = themeManager.themeRevision
        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(theme.progressTrack)

                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(fillColor)
                    .frame(width: max(geometry.size.width * clampedProgress, clampedProgress > 0 ? 4 : 0))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
