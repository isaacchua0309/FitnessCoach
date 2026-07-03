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
}

// MARK: - Phase badge

struct TodayHealthIntelligencePhaseBadge: View {
    let phase: TodayRecoveryCardPhase

    var body: some View {
        Text(label)
            .font(FormaTokens.Typography.caption2.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, FormaTokens.Spacing.sm)
            .padding(.vertical, TodayLayout.compactSpacing)
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
            return FormaTokens.Color.success
        case .moderate:
            return FormaTokens.Color.textSecondary
        case .low:
            return FormaTokens.Color.warning
        case .unknown, .limitedEstimate:
            return FormaTokens.Color.textTertiary
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.14)
    }

    private var accessibilityLabel: String {
        "Recovery status, \(label)"
    }
}

// MARK: - Guidance row

struct TodayHealthIntelligenceGuidanceRow: View {
    let text: String
    var iconName: String = "circle.fill"
    var iconColor: Color = FormaTokens.Theme.primary

    var body: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
            Image(systemName: iconName)
                .font(FormaTokens.Typography.caption2.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: TodayLayout.actionIconColumnWidth, alignment: .center)
                .padding(.top, 2)
                .accessibilityHidden(true)

            Text(text)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Card note

struct TodayHealthIntelligenceCardNote: View {
    let text: String
    var tone: Tone = .neutral

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
            return FormaTokens.Color.textTertiary
        case .caution:
            return FormaTokens.Color.warning
        }
    }
}

// MARK: - Loading card

struct TodayHealthIntelligenceLoadingCard<Content: View>: View {
    var isLoading: Bool
    @ViewBuilder var content: Content

    var body: some View {
        content
            .redacted(reason: isLoading ? .placeholder : [])
            .allowsHitTesting(!isLoading)
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
