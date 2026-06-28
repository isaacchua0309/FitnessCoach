//
//  BirthDateAgeResolver.swift
//  Fitness Coach
//
//  Forma — Calendar-safe age derivation and legacy age fallbacks.
//

import Foundation

enum BirthDateAgeResolver {

    static let minimumAge = 16
    static let maximumAge = 90

    /// Full-year age between `birthDate` and `referenceDate`.
    static func age(
        from birthDate: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let normalizedBirth = calendar.startOfDay(for: birthDate)
        let normalizedReference = calendar.startOfDay(for: referenceDate)
        let components = calendar.dateComponents([.year], from: normalizedBirth, to: normalizedReference)
        return max(0, components.year ?? 0)
    }

    /// Approximate date of birth for legacy age-only profiles and draft migration.
    static func syntheticBirthDate(
        fromAge age: Int,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let clampedAge = min(max(age, minimumAge), maximumAge)
        let normalizedReference = calendar.startOfDay(for: referenceDate)
        return calendar.date(byAdding: .year, value: -clampedAge, to: normalizedReference)
            ?? normalizedReference
    }

    /// Prefer birthday-derived age; fall back to stored legacy age.
    static func resolvedAge(
        birthDate: Date?,
        legacyAge: Int,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        if let birthDate {
            return age(from: birthDate, referenceDate: referenceDate, calendar: calendar)
        }
        return legacyAge
    }

    static func isValidAge(_ age: Int) -> Bool {
        (minimumAge...maximumAge).contains(age)
    }

    static func isValidBirthDate(
        _ birthDate: Date,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        isValidAge(age(from: birthDate, referenceDate: referenceDate, calendar: calendar))
    }
}

enum BirthDatePersistence {

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static func encode(_ date: Date) -> String {
        formatter.string(from: date)
    }

    static func decode(_ string: String) -> Date? {
        formatter.date(from: string)
    }
}

extension UserProfile {

    func resolvedAge(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        BirthDateAgeResolver.resolvedAge(
            birthDate: birthDate,
            legacyAge: age,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }
}
