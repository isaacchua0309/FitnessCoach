//
//  JourneyConsistencyCalendarSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyConsistencyCalendarSection: View {
    let calendar: JourneyConsistencyCalendar
    var onLogToday: (() -> Void)?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    @ScaledMetric(relativeTo: .caption) private var dayCellHeight: CGFloat = 30

    var body: some View {
        switch calendar.displayMode {
        case .momentumEmpty:
            momentumEmptySection
        case .consistencySummary:
            consistencySection(showsCalendarGrid: false)
        case .fullCalendar:
            consistencySection(showsCalendarGrid: true)
        }
    }

    // MARK: - Momentum empty

    private var momentumEmptySection: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            JourneySectionLabel(title: FormaProductCopy.Journey.sectionBuildRhythm)

            FormaEmptyStateCard(
                message: FormaProductCopy.EmptyState.Consistency.body,
                actionTitle: onLogToday == nil ? nil : FormaProductCopy.EmptyState.Consistency.action,
                action: onLogToday,
                actionAccessibilityHint: FormaProductCopy.EmptyState.Consistency.actionAccessibilityHint
            )
        }
    }

    // MARK: - Consistency

    private func consistencySection(showsCalendarGrid: Bool) -> some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            consistencyHeader

            if showsCalendarGrid {
                FitPilotPlanCard {
                    calendarGridContent
                }
            } else {
                FitPilotPlanCard {
                    Text(FormaProductCopy.Journey.consistencySubtitle)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var consistencyHeader: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                    JourneySectionLabel(title: FormaProductCopy.Journey.sectionConsistency)
                    Spacer(minLength: FormaTokens.Spacing.xs)
                    loggedDaysStat(alignment: .trailing)
                }

                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                    JourneySectionLabel(title: FormaProductCopy.Journey.sectionConsistency)
                    loggedDaysStat(alignment: .leading)
                }
            }

            if calendar.displayMode == .fullCalendar {
                Text(FormaProductCopy.Journey.consistencySubtitle)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var calendarGridContent: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            Text(calendar.monthTitle)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textPrimary)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(calendar.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.prefix(1))
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .frame(maxWidth: .infinity)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }

                ForEach(calendar.days) { day in
                    if let dayNumber = day.dayNumber {
                        dayCell(dayNumber: dayNumber, isCompleted: day.isCompleted)
                    } else {
                        Color.clear.frame(height: dayCellHeight)
                    }
                }
            }
        }
    }

    private func loggedDaysStat(alignment: TextAlignment) -> some View {
        Text(FormaProductCopy.Journey.loggedDaysThisMonth(calendar.completedCount))
            .font(FormaTokens.Typography.caption)
            .foregroundStyle(FormaTokens.Color.textSecondary)
            .multilineTextAlignment(alignment)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func dayCell(dayNumber: Int, isCompleted: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    isCompleted
                        ? FormaTokens.Color.accent.opacity(0.8)
                        : FormaTokens.Color.surfaceSubtle
                )
                .frame(height: dayCellHeight)

            Text("\(dayNumber)")
                .font(FormaTokens.Typography.caption.weight(isCompleted ? .semibold : .regular))
                .foregroundStyle(
                    isCompleted
                        ? FormaTokens.Color.canvas
                        : FormaTokens.Color.textSecondary
                )
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
        .accessibilityLabel(
            isCompleted
                ? "\(dayNumber), logged"
                : "\(dayNumber), not logged"
        )
    }
}
