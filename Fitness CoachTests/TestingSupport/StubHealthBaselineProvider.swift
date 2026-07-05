//
//  StubHealthBaselineProvider.swift
//  Fitness CoachTests
//

import Foundation
@testable import Fitness_Coach

struct StubHealthBaselineProvider: HealthBaselineProviding {
    func buildContext(for targetDate: Date, calendar: Calendar) async -> HealthBaselineContext {
        .empty(for: targetDate)
    }
}
