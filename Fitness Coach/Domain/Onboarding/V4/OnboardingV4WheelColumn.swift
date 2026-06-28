//
//  OnboardingV4WheelColumn.swift
//  Fitness Coach
//
//  Forma — Configuration models for v4 inline wheel pickers.
//

import Foundation

struct OnboardingV4WheelColumn<Value: Hashable>: Identifiable, Sendable {
    let id: String
    let accessibilityLabel: String
    let values: [Value]
    let format: (Value) -> String
}

enum OnboardingV4BirthdayWheelFactory {

    static func columns(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> (
        month: OnboardingV4WheelColumn<Int>,
        day: OnboardingV4WheelColumn<Int>,
        year: OnboardingV4WheelColumn<Int>
    ) {
        let yearRange = BirthDateAgeResolver.minimumAge...BirthDateAgeResolver.maximumAge
        let currentYear = calendar.component(.year, from: referenceDate)
        let years = stride(from: currentYear - BirthDateAgeResolver.maximumAge,
                           through: currentYear - BirthDateAgeResolver.minimumAge,
                           by: 1).map { $0 }

        let month = OnboardingV4WheelColumn(
            id: "month",
            accessibilityLabel: "Month",
            values: Array(1...12),
            format: { monthNumber in
                calendar.shortMonthSymbols[monthNumber - 1]
            }
        )

        let day = OnboardingV4WheelColumn(
            id: "day",
            accessibilityLabel: "Day",
            values: Array(1...31),
            format: { "\($0)" }
        )

        let yearColumn = OnboardingV4WheelColumn(
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
