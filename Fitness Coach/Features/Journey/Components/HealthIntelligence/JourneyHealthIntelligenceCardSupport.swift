//
//  JourneyHealthIntelligenceCardSupport.swift
//  Fitness Coach
//
//  Forma — Shared styling for Journey Health Intelligence cards.
//

import SwiftUI

@MainActor
enum JourneyHealthIntelligenceCardSupport {
    static let cardContentSpacing = FormaTokens.Spacing.sm
    static let rowSpacing = FormaTokens.Spacing.xs
}

// MARK: - Loading wrapper

struct JourneyHealthIntelligenceLoadingCard<Content: View>: View {
    var isLoading: Bool
    @ViewBuilder var content: Content

    var body: some View {
        HealthIntelligenceLoadingContainer(isLoading: isLoading) {
            content
        }
    }
}

// MARK: - Recovery colors

@MainActor
enum JourneyHealthIntelligenceVisualSupport {

    static func recoveryColor(for kind: JourneyRecoveryDayStatusKind) -> Color {
        switch kind {
        case .ready:
            return FormaTokens.Color.success
        case .moderate:
            return FormaTokens.Color.progress
        case .low:
            return FormaTokens.Color.warning
        case .limitedEstimate:
            return FormaTokens.Color.textTertiary
        case .unknown:
            return FormaTokens.Color.progressTrack
        }
    }

    static func recoveryColor(for token: String) -> Color {
        switch token {
        case "recoveryReady":
            return FormaTokens.Color.success
        case "recoveryModerate":
            return FormaTokens.Color.progress
        case "recoveryLow":
            return FormaTokens.Color.warning
        case "recoveryLimited":
            return FormaTokens.Color.textTertiary
        default:
            return FormaTokens.Color.progressTrack
        }
    }

    static func milestoneStatusColor(for status: JourneyHealthMilestoneStatus) -> Color {
        switch status {
        case .achieved:
            return FormaTokens.Color.success
        case .inProgress:
            return FormaTokens.Theme.primary
        case .upcoming:
            return FormaTokens.Color.textTertiary
        }
    }
}

// MARK: - Recovery day dot

struct JourneyRecoveryDayDot: View {
    let day: JourneyRecoveryDayState
    var isToday: Bool = false

    @ScaledMetric(relativeTo: .caption) private var dotSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var todayRingSize: CGFloat = 16

    var body: some View {
        VStack(spacing: JourneyLayout.compactSpacing) {
            ZStack {
                if isToday {
                    Circle()
                        .strokeBorder(
                            FormaTokens.Theme.primary.opacity(0.45),
                            lineWidth: 1.5
                        )
                        .frame(width: todayRingSize, height: todayRingSize)
                }

                Circle()
                    .fill(JourneyHealthIntelligenceVisualSupport.recoveryColor(for: day.statusKind))
                    .frame(width: dotSize, height: dotSize)
            }
            .frame(height: todayRingSize)

            Text(day.weekdayLabel)
                .font(FormaTokens.Typography.caption2)
                .foregroundStyle(
                    isToday
                        ? FormaTokens.Color.textPrimary
                        : FormaTokens.Color.textTertiary
                )
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let score = day.recoveryScore {
                Text("\(score)")
                    .font(FormaTokens.Typography.caption2.weight(.medium))
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .lineLimit(1)
            } else if day.isLimitedEstimate, let label = day.limitedEstimateLabel {
                Text(label)
                    .font(FormaTokens.Typography.caption2)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.accessibilityLabel)
    }
}

// MARK: - Recovery week row

struct JourneyRecoveryWeekRow: View {
    let days: [JourneyRecoveryDayState]
    var referenceDay: Date?

    private var calendar: Calendar { .current }

    var body: some View {
        HStack(alignment: .top, spacing: JourneyLayout.compactSpacing) {
            ForEach(days) { day in
                JourneyRecoveryDayDot(
                    day: day,
                    isToday: isToday(day)
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(recoveryWeekAccessibilityLabel)
    }

    private func isToday(_ day: JourneyRecoveryDayState) -> Bool {
        guard let referenceDay else { return false }
        return calendar.isDate(day.date, inSameDayAs: referenceDay)
    }

    private var recoveryWeekAccessibilityLabel: String {
        let summaries = days.map(\.accessibilityLabel)
        return "Recovery week. \(summaries.joined(separator: ". "))"
    }
}

// MARK: - Milestone chip

struct JourneyHealthMilestoneChip: View {
    let milestone: JourneyHealthMilestoneState

    @ScaledMetric(relativeTo: .caption) private var chipDotSize: CGFloat = 6

    var body: some View {
        HStack(spacing: JourneyLayout.compactSpacing) {
            Circle()
                .fill(JourneyHealthIntelligenceVisualSupport.milestoneStatusColor(for: milestone.status))
                .frame(width: chipDotSize, height: chipDotSize)
                .accessibilityHidden(true)

            Text(milestone.title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, FormaTokens.Spacing.sm)
        .padding(.vertical, FormaTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(FormaTokens.Theme.softBackground.opacity(HealthIntelligenceCardLayout.chipBackgroundOpacity))
        )
        .overlay {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .stroke(
                    FormaTokens.Theme.borderTint.opacity(HealthIntelligenceCardLayout.chipBorderOpacity),
                    lineWidth: 0.5
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(milestone.accessibilityLabel)
        .formaThemeReactive()
    }
}

// MARK: - Phase messages

struct JourneyHealthIntelligencePhaseMessage: View {
    let message: String
    var tone: Tone = .neutral

    enum Tone {
        case neutral
        case caution
    }

    var body: some View {
        Text(message)
            .font(JourneyTypography.cardSupporting)
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
