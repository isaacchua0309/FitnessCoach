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

struct SystemDateProvider: DateProviding {
    var now: Date { Date() }

    func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
