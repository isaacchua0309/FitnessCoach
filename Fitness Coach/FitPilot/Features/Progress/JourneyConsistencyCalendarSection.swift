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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(calendar.monthTitle)
                .font(.subheadline.weight(.medium))

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(calendar.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.prefix(1))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendar.days) { day in
                    if let dayNumber = day.dayNumber {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(day.isCompleted ? Color.primary.opacity(0.75) : Color.secondary.opacity(0.12))
                                .frame(height: 32)
                            Text("\(dayNumber)")
                                .font(.caption2.weight(day.isCompleted ? .semibold : .regular))
                                .foregroundStyle(day.isCompleted ? Color(.systemBackground) : .secondary)
                        }
                    } else {
                        Color.clear.frame(height: 32)
                    }
                }
            }
        }
    }
}
