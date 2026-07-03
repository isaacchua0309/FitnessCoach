//
//  PlanHealthIntelligenceLoadResult.swift
//  Fitness Coach
//
//  Forma — Single-load result for Plan Health Intelligence section composition.
//

import Foundation

struct PlanHealthIntelligenceLoadResult: Sendable {
    let sectionState: PlanHealthIntelligenceSectionState
    let snapshot: HealthIntelligenceSnapshot?
    let availability: HealthDataAvailability
}
