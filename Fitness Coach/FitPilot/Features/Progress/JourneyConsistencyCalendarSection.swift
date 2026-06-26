//
//  JourneyConsistencyCalendarSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyConsistencyCalendarSection: View {
    let calendar: JourneyConsistencyCalendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            HStack {
                JourneySectionLabel(title: "Consistency")
                Spacer()
                Text("\(calendar.completedCount) days")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
            }

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(calendar.monthTitle)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                        .foregroundStyle(FormaTokens.Color.textPrimary)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(calendar.weekdaySymbols, id: \.self) { symbol in
                            Text(symbol.prefix(1))
                                .font(FormaTokens.Typography.caption)
                                .foregroundStyle(FormaTokens.Color.textTertiary)
                                .frame(maxWidth: .infinity)
                        }

                        ForEach(calendar.days) { day in
                            if let dayNumber = day.dayNumber {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(day.isCompleted ? FormaTokens.Color.accent.opacity(0.85) : FormaTokens.Color.surfaceSubtle)
                                        .frame(height: 32)
                                    Text("\(dayNumber)")
                                        .font(FormaTokens.Typography.caption.weight(day.isCompleted ? .semibold : .regular))
                                        .foregroundStyle(day.isCompleted ? FormaTokens.Color.canvas : FormaTokens.Color.textSecondary)
                                }
                            } else {
                                Color.clear.frame(height: 32)
                            }
                        }
                    }
                }
            }
        }
    }
}
