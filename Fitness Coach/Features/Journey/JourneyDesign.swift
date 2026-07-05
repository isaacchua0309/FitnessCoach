//
//  JourneyDesign.swift
//  Fitness Coach
//
//  Forma — Shared visual language for the Journey tab (calm, reflective, hierarchical).
//

import SwiftUI

// MARK: - Section labels

// MARK: - Cards

enum JourneyCardElevation {
    /// Flagship transformation hero — accent stripe, generous padding.
    case hero
    /// Milestones and goal projection — standard accent card.
    case featured
    /// Weekly review and recap — default dashboard card.
    case standard
    /// Timeline, insights, chapters — softer secondary surfaces.
    case quiet
}

struct JourneyCard<Content: View>: View {
    let elevation: JourneyCardElevation
    @ViewBuilder var content: Content

    var body: some View {
        MainTabCard(style: cardStyle, compact: isCompact) {
            content
        }
    }

    private var cardStyle: FormaCardChrome.Style {
        switch elevation {
        case .hero:
            return .accentLeading
        case .featured, .standard:
            return .surface
        case .quiet:
            return .surfaceSubtle
        }
    }

    private var isCompact: Bool {
        switch elevation {
        case .hero, .featured:
            return false
        case .standard, .quiet:
            return true
        }
    }
}

// MARK: - Progress

struct JourneyProgressBar: View {
    let progress: Double
    var height: CGFloat = JourneyLayout.progressBarHeight
    var prominent: Bool = false

    @Environment(\.theme) private var theme

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var displayFill: Double {
        let fill = clampedProgress
        guard fill > 0 else { return 0 }
        return max(fill, 0.04)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(theme.progressTrack)

                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(theme.progressFill.opacity(prominent ? 1 : 0.88))
                    .frame(
                        width: max(
                            geometry.size.width * displayFill,
                            displayFill > 0 ? height : 0
                        )
                    )
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Momentum chip

struct JourneyMomentumChip: View {
    let headline: String
    let detail: String?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
            Text(headline)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(theme.accent)
                .fixedSize(horizontal: false, vertical: true)

            if let detail {
                Text(detail)
                    .font(FormaTokens.Typography.caption2)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, FormaTokens.Spacing.sm)
        .padding(.vertical, FormaTokens.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(theme.accentSoftBackground.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .stroke(theme.accentBorder.opacity(0.78), lineWidth: 0.5)
        }
    }
}

// MARK: - Milestone icon

struct JourneyMilestoneIcon: View {
    let symbol: String

    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .title3) private var orbSize: CGFloat = 40
    @ScaledMetric(relativeTo: .title3) private var symbolSize: CGFloat = 22

    var body: some View {
        Text(symbol)
            .font(.system(size: symbolSize))
            .frame(width: orbSize, height: orbSize)
            .background(
                Circle()
                    .fill(theme.accentSoftBackground.opacity(0.85))
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Day dots

struct JourneyDayDotRow: View {
    let cells: [Bool]

    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .caption) private var dotSize: CGFloat = 8

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, isMet in
                Circle()
                    .fill(isMet ? theme.progressFill : theme.progressTrack)
                    .frame(width: dotSize, height: dotSize)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Copy styles

enum JourneyTypography {
    static let heroHeadline = Font.system(.title, design: .rounded).weight(.bold)
    static let cardHeadline = Font.subheadline.weight(.semibold)
    static let cardSupporting = Font.caption
    static let cardDetail = Font.subheadline
    static let metricValue = Font.subheadline.weight(.semibold)
    static let metricLabel = Font.subheadline.weight(.medium)
}
