//
//  WeeklyReviewCardSupport.swift
//  Fitness Coach
//
//  Forma — Shared styling for Weekly Review presentation components.
//

import SwiftUI

enum WeeklyReviewCardSupport {
    static let contentSpacing = FormaTokens.Spacing.sm
    static let sectionSpacing = FormaTokens.Spacing.xs
    static let listSpacing = JourneyLayout.compactSpacing
}

// MARK: - Loading wrapper

struct WeeklyReviewLoadingContainer<Content: View>: View {
    var isLoading: Bool
    @ViewBuilder var content: Content

    var body: some View {
        content
            .redacted(reason: isLoading ? .placeholder : [])
            .allowsHitTesting(!isLoading)
    }
}

// MARK: - Typography

enum WeeklyReviewTypography {
    static let cardTitle = JourneyTypography.cardHeadline
    static let reportTitle = Font.title3.weight(.semibold)
    static let body = JourneyTypography.cardSupporting
    static let eyebrow = FormaTokens.Typography.caption2.weight(.semibold)
    static let statValue = JourneyTypography.metricValue
    static let statLabel = FormaTokens.Typography.caption.weight(.medium)
}

// MARK: - Badges

struct WeeklyReviewConfidenceBadge: View {
    let label: String
    var isLimited: Bool = false

    var body: some View {
        Text(label)
            .font(FormaTokens.Typography.caption2.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, FormaTokens.Spacing.sm)
            .padding(.vertical, JourneyLayout.compactSpacing)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
            )
            .accessibilityLabel("Confidence, \(label)")
    }

    private var foregroundColor: Color {
        isLimited ? FormaTokens.Color.warning : FormaTokens.Color.textSecondary
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.14)
    }
}

struct WeeklyReviewHeadlineStatBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(FormaTokens.Theme.primary)
            .padding(.horizontal, FormaTokens.Spacing.sm)
            .padding(.vertical, JourneyLayout.compactSpacing)
            .background(
                Capsule(style: .continuous)
                    .fill(FormaTokens.Theme.softBackground.opacity(0.72))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(FormaTokens.Theme.borderTint.opacity(0.35), lineWidth: 0.5)
            }
            .accessibilityLabel(label)
    }
}

// MARK: - Section header

struct WeeklyReviewSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(WeeklyReviewTypography.eyebrow)
            .foregroundStyle(FormaTokens.Color.textTertiary)
            .textCase(.uppercase)
            .tracking(0.5)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Phase message

struct WeeklyReviewPhaseMessage: View {
    let message: String
    var tone: Tone = .neutral

    enum Tone {
        case neutral
        case caution
    }

    var body: some View {
        Text(message)
            .font(WeeklyReviewTypography.body)
            .foregroundStyle(foregroundColor)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
    }

    private var foregroundColor: Color {
        switch tone {
        case .neutral:
            return FormaTokens.Color.textSecondary
        case .caution:
            return FormaTokens.Color.warning
        }
    }
}
