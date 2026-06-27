//
//  TodayLayout.swift
//  Fitness Coach
//
//  Forma — Shared spacing and card chrome for the Today screen.
//

import SwiftUI

enum TodayLayout {
    /// Space between major blocks (hero, meals, Coach CTA).
    static let sectionSpacing = FormaTokens.Spacing.xl
    /// Tighter stack for focus → actions → targets.
    static let planBlockSpacing = FormaTokens.Spacing.md
    /// Label to card within a section.
    static let headerToCardSpacing = FormaTokens.Spacing.xs
    static let itemSpacing = FormaTokens.Spacing.sm
    static let horizontalPadding = FormaTokens.Spacing.pageHorizontal
    static let actionIconColumnWidth: CGFloat = 22
    static let metricsProgressHeight: CGFloat = 6
    /// Scroll padding below the Coach CTA so content clears the tab bar.
    static let bottomScrollPadding = FormaTokens.Spacing.xl + FormaTokens.Spacing.sm
}

struct TodaySectionLabel: View {
    let title: String

    var body: some View {
        FormaSectionLabel(title: title)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Focus

struct TodayFocusCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground(accentLeading: true))
    }
}

// MARK: - Next Actions

struct TodayActionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground(accentLeading: true))
    }
}

// MARK: - Today's Targets

struct TodayMetricsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground(accentLeading: false))
    }
}

struct TodayMetricProgressBar: View {
    let progress: Double

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(FormaTokens.Color.surfaceSubtle)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(FormaTokens.Color.accent.opacity(0.78))
                    .frame(width: max(geometry.size.width * clampedProgress, clampedProgress > 0 ? 4 : 0))
            }
        }
        .frame(height: TodayLayout.metricsProgressHeight)
        .accessibilityHidden(true)
    }
}

// MARK: - Shared card chrome

private func cardBackground(accentLeading: Bool) -> some View {
    RoundedRectangle(cornerRadius: FitPilotScreenStyle.cardCornerRadius, style: .continuous)
        .fill(FormaTokens.Color.surface)
        .overlay {
            RoundedRectangle(cornerRadius: FitPilotScreenStyle.cardCornerRadius, style: .continuous)
                .stroke(
                    accentLeading
                        ? LinearGradient(
                            colors: [
                                FormaTokens.Color.accent.opacity(0.22),
                                FormaTokens.Color.border
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [FormaTokens.Color.border, FormaTokens.Color.border],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                    lineWidth: 1
                )
        }
        .overlay(alignment: .leading) {
            if accentLeading {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(FormaTokens.Color.accent.opacity(0.55))
                    .frame(width: 3)
                    .padding(.vertical, FormaTokens.Spacing.sm)
                    .padding(.leading, 1)
            }
        }
}
