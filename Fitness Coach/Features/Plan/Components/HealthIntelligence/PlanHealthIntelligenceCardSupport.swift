//
//  PlanHealthIntelligenceCardSupport.swift
//  Fitness Coach
//
//  Forma — Shared styling for Plan Health Intelligence presentation components.
//

import SwiftUI

enum PlanHealthIntelligenceCardSupport {
    static let headerToCardSpacing = FormaTokens.Spacing.xs
    static let contentSpacing = FormaTokens.Spacing.sm
    static let rowSpacing = FormaTokens.Spacing.xs
    static let actionSpacing = FormaTokens.Spacing.md
}

// MARK: - Loading wrapper

struct PlanHealthIntelligenceLoadingContainer<Content: View>: View {
    var isLoading: Bool
    @ViewBuilder var content: Content

    var body: some View {
        content
            .redacted(reason: isLoading ? .placeholder : [])
            .allowsHitTesting(!isLoading)
    }
}

// MARK: - Typography

enum PlanHealthIntelligenceTypography {
    static let cardHeadline = FormaTokens.Typography.sectionTitle.weight(.bold)
    static let cardBody = FormaTokens.Typography.sectionSubtitle
    static let cardCaption = FormaTokens.Typography.caption
    static let rowLabel = FormaTokens.Typography.sectionSubtitle
    static let rowValue = FormaTokens.Typography.sectionSubtitle.weight(.medium)
}

// MARK: - Visual support

enum PlanHealthIntelligenceVisualSupport {

    static func confidenceAccentColor(for label: String) -> Color {
        switch label {
        case FormaProductCopy.PlanHealthIntelligencePresentation.confidenceHigh:
            return FormaTokens.Color.success
        case FormaProductCopy.PlanHealthIntelligencePresentation.confidenceModerate:
            return FormaTokens.Theme.primary
        case FormaProductCopy.PlanHealthIntelligencePresentation.confidenceLow:
            return FormaTokens.Color.warning
        default:
            return FormaTokens.Color.textSecondary
        }
    }

    static func dataQualityAccentColor(for level: PlanHealthDataQualityLevel) -> Color {
        switch level {
        case .strong:
            return FormaTokens.Color.success
        case .moderate:
            return FormaTokens.Theme.primary
        case .limited:
            return FormaTokens.Color.warning
        }
    }

    static func signalStatusColor(for status: PlanHealthSignalStatus) -> Color {
        switch status {
        case .available:
            return FormaTokens.Color.success
        case .limited:
            return FormaTokens.Color.warning
        case .missing:
            return FormaTokens.Color.textTertiary
        }
    }

    static func friendlySignalStatusLabel(for status: PlanHealthSignalStatus) -> String {
        let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
        switch status {
        case .available:
            return copy.signalSynced
        case .limited:
            return copy.signalPartialSync
        case .missing:
            return copy.signalUnavailable
        }
    }

    static func displayValue(for signal: PlanHealthSignalState) -> String {
        switch signal.status {
        case .available:
            return signal.value
        case .limited:
            return signal.detail ?? friendlySignalStatusLabel(for: signal.status)
        case .missing:
            return friendlySignalStatusLabel(for: signal.status)
        }
    }
}

// MARK: - Badges

struct PlanHealthConfidenceBadge: View {
    let label: String

    var body: some View {
        Text(label)
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(PlanHealthIntelligenceVisualSupport.confidenceAccentColor(for: label))
            .padding(.horizontal, FormaTokens.Spacing.sm)
            .padding(.vertical, PlanHealthIntelligenceCardSupport.rowSpacing)
            .background(
                Capsule(style: .continuous)
                    .fill(PlanHealthIntelligenceVisualSupport.confidenceAccentColor(for: label).opacity(0.14))
            )
            .accessibilityLabel("Confidence, \(label)")
    }
}

struct PlanHealthScoreBadge: View {
    let scorePercent: Int

    var body: some View {
        Text("\(scorePercent)% fit")
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(FormaTokens.Theme.primary)
            .padding(.horizontal, FormaTokens.Spacing.sm)
            .padding(.vertical, PlanHealthIntelligenceCardSupport.rowSpacing)
            .background(
                Capsule(style: .continuous)
                    .fill(FormaTokens.Theme.softBackground.opacity(0.72))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(FormaTokens.Theme.borderTint.opacity(0.35), lineWidth: 0.5)
            }
            .accessibilityLabel("\(scorePercent) percent plan fit")
    }
}

struct PlanHealthDataQualityBadge: View {
    let level: PlanHealthDataQualityLevel
    let label: String

    var body: some View {
        Text(label)
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(PlanHealthIntelligenceVisualSupport.dataQualityAccentColor(for: level))
            .padding(.horizontal, FormaTokens.Spacing.sm)
            .padding(.vertical, PlanHealthIntelligenceCardSupport.rowSpacing)
            .background(
                Capsule(style: .continuous)
                    .fill(PlanHealthIntelligenceVisualSupport.dataQualityAccentColor(for: level).opacity(0.14))
            )
            .accessibilityLabel(label)
    }
}

// MARK: - Rows

struct PlanHealthSignalStatusRow: View {
    let signal: PlanHealthSignalState

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Circle()
                .fill(PlanHealthIntelligenceVisualSupport.signalStatusColor(for: signal.status))
                .frame(width: 8, height: 8)
                .padding(.top, 5)
                .accessibilityHidden(true)

            Text(signal.title)
                .font(PlanHealthIntelligenceTypography.rowLabel)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(PlanHealthIntelligenceVisualSupport.displayValue(for: signal))
                .font(PlanHealthIntelligenceTypography.rowValue)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(signal.accessibilityLabel)
    }
}

struct PlanHealthReasonBulletRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
            Text("•")
                .font(PlanHealthIntelligenceTypography.rowLabel.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .frame(width: 14, alignment: .leading)
                .accessibilityHidden(true)

            Text(text)
                .font(PlanHealthIntelligenceTypography.cardBody)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityLabel(text)
    }
}

struct PlanHealthPhaseMessage: View {
    let message: String
    var tone: Tone = .neutral

    enum Tone {
        case neutral
        case caution
    }

    var body: some View {
        Text(message)
            .font(PlanHealthIntelligenceTypography.cardBody)
            .foregroundStyle(foregroundColor)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(nil)
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
