//
//  TodayHealthIntelligenceCardSupport.swift
//  Fitness Coach
//
//  Forma — Shared styling for Today Health Intelligence cards.
//

import SwiftUI

enum TodayHealthIntelligenceCardSupport {

    static let cardContentSpacing = FormaTokens.Spacing.sm
    static let guidanceSpacing = FormaTokens.Spacing.xs
    static let cardInnerVerticalPadding = HealthIntelligenceCardLayout.cardInnerVerticalPadding
}

// MARK: - Phase badge

struct TodayHealthIntelligencePhaseBadge: View {
    let phase: TodayRecoveryCardPhase

    @Environment(\.formaColors) private var colors
    @ScaledMetric(relativeTo: .caption) private var verticalPadding: CGFloat = 4

    var body: some View {
        Text(label)
            .font(FormaTokens.Typography.caption2.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, FormaTokens.Spacing.sm)
            .padding(.vertical, verticalPadding)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
            )
            .accessibilityLabel(accessibilityLabel)
    }

    private var label: String {
        switch phase {
        case .ready:
            return "Ready"
        case .moderate:
            return "Moderate"
        case .low:
            return "Low"
        case .unknown:
            return "Unclear"
        case .limitedEstimate:
            return FormaProductCopy.Today.HealthIntelligence.limitedEstimate
        }
    }

    private var foregroundColor: Color {
        switch phase {
        case .ready:
            return colors.success
        case .moderate:
            return colors.textSecondary
        case .low:
            return colors.warning
        case .unknown, .limitedEstimate:
            return colors.textTertiary
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(HealthIntelligenceCardLayout.badgeBackgroundOpacity)
    }

    private var accessibilityLabel: String {
        "Recovery status, \(label)"
    }
}

// MARK: - Guidance row

enum TodayGuidanceIconAccent: Equatable {
    case primary
    case secondary
    case tertiary
}

struct TodayHealthIntelligenceGuidanceRow: View {
    let text: String
    var iconName: String = "circle.fill"
    var iconAccent: TodayGuidanceIconAccent = .primary

    @Environment(\.themePalette) private var palette
    @Environment(\.formaColors) private var colors

    private var resolvedIconColor: Color {
        switch iconAccent {
        case .primary:
            return palette.primary
        case .secondary:
            return palette.secondary
        case .tertiary:
            return colors.textTertiary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Image(systemName: iconName)
                .font(FormaTokens.Typography.caption2.weight(.semibold))
                .foregroundStyle(resolvedIconColor)
                .frame(width: TodayLayout.actionIconColumnWidth, alignment: .center)
                .padding(.top, 2)
                .accessibilityHidden(true)

            Text(text)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .accessibilityElement(children: .combine)
        .formaThemeReactive()
    }
}

// MARK: - Card note

struct TodayHealthIntelligenceCardNote: View {
    let text: String
    var tone: Tone = .neutral

    @Environment(\.formaColors) private var colors

    enum Tone {
        case neutral
        case caution
    }

    var body: some View {
        Text(text)
            .font(FormaTokens.Typography.caption)
            .foregroundStyle(foregroundColor)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
    }

    private var foregroundColor: Color {
        switch tone {
        case .neutral:
            return colors.textTertiary
        case .caution:
            return colors.warning
        }
    }
}

// MARK: - Loading card

struct TodayHealthIntelligenceLoadingCard<Content: View>: View {
    var isLoading: Bool
    @ViewBuilder var content: Content

    var body: some View {
        HealthIntelligenceLoadingContainer(isLoading: isLoading) {
            content
        }
    }
}

// MARK: - Card typography helpers

enum TodayHealthIntelligenceCardTypography {
    static var headline: Font {
        FormaTokens.Typography.sectionSubtitle.weight(.semibold)
    }

    static var body: Font {
        FormaTokens.Typography.body
    }

    static var detail: Font {
        FormaTokens.Typography.caption
    }
}
