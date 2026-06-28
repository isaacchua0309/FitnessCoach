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
    static let itemSpacing = FormaTokens.Spacing.sm
    static let horizontalPadding = FormaTokens.Spacing.pageHorizontal
    static let actionIconColumnWidth: CGFloat = 22
    static let metricsProgressHeight: CGFloat = 4
    /// Scroll padding below the last Today section (see `FormaMainTabLayout`).
    static let bottomScrollPadding = FormaMainTabLayout.scrollContentBottomPadding
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
            .padding(.vertical, FormaTokens.Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground(accentLeading: true))
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
            .background(metricsCardBackground())
    }
}

struct TodayMetricProgressBar: View {
    let progress: Double
    var subdued: Bool = true

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(FormaTokens.Color.surface)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        FormaTokens.Color.accent.opacity(subdued ? 0.42 : 0.78)
                    )
                    .frame(width: max(geometry.size.width * clampedProgress, clampedProgress > 0 ? 3 : 0))
            }
        }
        .frame(height: TodayLayout.metricsProgressHeight)
        .accessibilityHidden(true)
    }
}

// MARK: - Shared card chrome

private func metricsCardBackground() -> some View {
    RoundedRectangle(cornerRadius: FitPilotScreenStyle.cardCornerRadius, style: .continuous)
        .fill(FormaTokens.Color.surfaceSubtle)
        .overlay {
            RoundedRectangle(cornerRadius: FitPilotScreenStyle.cardCornerRadius, style: .continuous)
                .stroke(FormaTokens.Color.border.opacity(0.55), lineWidth: 0.5)
        }
}

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
