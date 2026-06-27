//
//  DateProvider.swift
//  Fitness Coach
//
//  FitPilot AI — Minimal date abstraction for services.
//

import Foundation

protocol DateProviding {
    var now: Date { get }
    func startOfDay(for date: Date) -> Date
}

struct SystemDateProvider: DateProviding, Sendable {
    nonisolated init() {}

    nonisolated var now: Date { Date() }

    nonisolated func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
