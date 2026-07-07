//
//  TodayHealthIntelligenceLoadResult.swift
//  Fitness Coach
//
//  Forma — Single-load result for Today Health Intelligence section composition.
//

import Foundation

struct TodayHealthIntelligenceLoadResult: Sendable {
    let sectionState: TodayHealthIntelligenceSectionState?
    let snapshot: HealthIntelligenceSnapshot?
    let availability: HealthDataAvailability?
    let analyticsContext: HealthIntelligencePresentationContext
}
