//
//  PlanDashboardCompositionPolicy.swift
//  Fitness Coach
//
//  Forma — Section visibility rules when Health Intelligence UI is enabled.
//

import Foundation

enum PlanDashboardCompositionPolicy {

    static func showsHealthIntelligenceSection(
        isUIEnabled: Bool,
        sectionState: PlanHealthIntelligenceSectionState?
    ) -> Bool {
        isUIEnabled && sectionState != nil
    }

    /// Legacy Apple Health connection/confidence card duplicates PlanHealthIntelligenceSection.
    static func showsLegacyPlanConfidenceSection(
        isUIEnabled: Bool,
        sectionState: PlanHealthIntelligenceSectionState?
    ) -> Bool {
        !showsHealthIntelligenceSection(isUIEnabled: isUIEnabled, sectionState: sectionState)
    }
}
