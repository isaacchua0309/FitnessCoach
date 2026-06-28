//
//  OnboardingWheelColumn.swift
//  Fitness Coach
//
//  Forma — Configuration models for inline wheel pickers.
//

import Foundation

struct OnboardingWheelColumn<Value: Hashable>: Identifiable, Sendable {
    let id: String
    let accessibilityLabel: String
    let values: [Value]
    let format: (Value) -> String
}

enum OnboardingBirthdayWheelFactory {

    static func columns(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> (
        month: OnboardingWheelColumn<Int>,
        day: OnboardingWheelColumn<Int>,
        year: OnboardingWheelColumn<Int>
    ) {
        let yearRange = BirthDateAgeResolver.minimumAge...BirthDateAgeResolver.maximumAge
        let currentYear = calendar.component(.year, from: referenceDate)
        let years = stride(from: currentYear - BirthDateAgeResolver.maximumAge,
                           through: currentYear - BirthDateAgeResolver.minimumAge,
                           by: 1).map { $0 }

        let month = OnboardingWheelColumn(
            id: "month",
            accessibilityLabel: "Month",
            values: Array(1...12),
            format: { monthNumber in
                calendar.shortMonthSymbols[monthNumber - 1]
            }
        )

        let day = OnboardingWheelColumn(
            id: "day",
            accessibilityLabel: "Day",
            values: Array(1...31),
            format: { "\($0)" }
        )

        let yearColumn = OnboardingWheelColumn(
            id: "year",
            accessibilityLabel: "Year",
            values: years,
            format: { "\($0)" }
        )

        _ = yearRange
        return (month, day, yearColumn)
    }

    static func birthDate(
        month: Int,
        day: Int,
        year: Int,
        calendar: Calendar = .current
    ) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }
}
