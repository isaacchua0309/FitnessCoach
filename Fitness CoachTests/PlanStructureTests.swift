//
//  PlanStructureTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanStructureTests: XCTestCase {

    func testProductSectionOrderMatchesCanonicalLayout() {
        XCTAssertEqual(PlanProductLayout.sectionOrder, [
            .header,
            .goalProgress,
            .todayMission,
            .planStatus,
            .whyThisWorks,
            .planConfidence,
            .whenToAdjust,
            .planAssumptions,
            .nextReview,
            .adjustPlanCTA
        ])
        XCTAssertEqual(PlanProductLayout.sectionOrder.first, .header)
        XCTAssertEqual(PlanProductLayout.sectionOrder.last, .adjustPlanCTA)
    }

    func testPrimaryAndSecondarySectionsComposeCanonicalOrder() {
        XCTAssertEqual(
            PlanProductLayout.primarySectionOrder + PlanProductLayout.secondarySectionOrder,
            PlanProductLayout.sectionOrder
        )
    }

    func testRemovedSectionsAreNotPartOfCanonicalOrder() {
        let identifiers = Set(PlanProductLayout.sectionOrder.map(\.rawValue))

        for removed in PlanProductLayout.removedSectionIdentifiers {
            XCTAssertFalse(
                identifiers.contains(removed),
                "Removed section \(removed) should not appear in canonical order"
            )
        }
    }

    func testPresentationSectionTitlesMatchProductLayout() {
        let dashboard = PlanMissionControlFixtures.loseDashboard

        XCTAssertEqual(dashboard.header.subtitle, FormaProductCopy.PlanHeader.subtitle)
        XCTAssertEqual(dashboard.strategy.sectionTitle, FormaProductCopy.PlanStrategyHero.sectionTitle)
        XCTAssertEqual(dashboard.dailyTargets.sectionTitle, "Daily Targets")
        XCTAssertEqual(dashboard.status.sectionTitle, "Plan Status")
        XCTAssertEqual(dashboard.explanation.sectionTitle, "Why This Works")
        XCTAssertEqual(dashboard.confidence.sectionTitle, "Plan Confidence")
        XCTAssertEqual(dashboard.adjustmentRules.sectionTitle, "When to Adjust")
        XCTAssertEqual(dashboard.assumptions.sectionTitle, "Plan Assumptions")
        XCTAssertEqual(dashboard.review.sectionTitle, "Next Review")
    }

    func testRationaleKeepsCalculationDetailsAccessible() throws {
        let profile = PlanMissionControlFixtures.loseProfile
        let result = try PlanCalculationBridge.planResult(from: profile)
        let rationale = PlanRationaleCopyBuilder.build(profile: profile, result: result)

        XCTAssertNotNil(rationale.calculationDetails)
        XCTAssertEqual(rationale.seeCalculationTitle, FormaProductCopy.PlanRationale.seeCalculation)
    }

    func testCanonicalLayoutExcludesLegacyProductSections() {
        XCTAssertFalse(PlanProductLayout.sectionOrder.map(\.rawValue).contains("what_happens_next"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("what_happens_next"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("current_strategy"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("todays_targets"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("plan_lifestyle"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("this_week"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("next_milestone"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("adjust_plan"))
    }

    func testDashboardStateEmbedsPresentationSectionsNotLegacyProductSections() {
        let state = PlanStateBuilder.dashboardState(profile: PlanMissionControlFixtures.loseProfile)

        XCTAssertEqual(state.strategy.goalDirection, .lose)
        XCTAssertFalse(state.dailyTargets.caloriesLabel.isEmpty)
        XCTAssertFalse(state.assumptions.rows.isEmpty)
        XCTAssertNotNil(state.explanation.calculationDetails)
    }

    func testLegacyPlanPageStringsDoNotAppearOnDashboard() {
        let forbiddenSectionTitles = [
            "Next Milestone",
            "This Week",
            "Activity Assumptions",
            "Complete 7 days of logging"
        ]

        for dashboard in [
            PlanMissionControlFixtures.loseDashboard,
            PlanMissionControlFixtures.activeUserDashboard,
            PlanMissionControlFixtures.newUserDashboard
        ] {
            let combined = planDashboardVisibleCopy(from: dashboard)

            for title in forbiddenSectionTitles {
                XCTAssertFalse(
                    combined.contains(title),
                    "Legacy section title '\(title)' should not appear on Plan dashboard"
                )
            }

            XCTAssertFalse(
                combined.contains("Current ") && combined.contains("→ Goal "),
                "Legacy progress route summary should not appear on Plan dashboard"
            )
            XCTAssertEqual(
                combined.components(separatedBy: "Plan Assumptions").count - 1,
                1,
                "Plan Assumptions should appear once, not as a duplicated card"
            )
        }
    }

    private func planDashboardVisibleCopy(from dashboard: PlanDashboardState) -> String {
        var parts = [
            dashboard.header.title,
            dashboard.header.subtitle,
            dashboard.strategy.sectionTitle,
            dashboard.strategy.primaryGoal,
            dashboard.strategy.supportiveLine,
            dashboard.dailyTargets.sectionTitle,
            dashboard.dailyTargets.prescriptionCopy,
            dashboard.status.sectionTitle,
            dashboard.status.statusName,
            dashboard.status.explanation,
            dashboard.explanation.sectionTitle,
            dashboard.explanation.guidanceCopy,
            dashboard.confidence.sectionTitle,
            dashboard.confidence.scoreHeadline,
            dashboard.adjustmentRules.sectionTitle,
            dashboard.assumptions.sectionTitle,
            dashboard.review.sectionTitle,
            dashboard.review.headline,
            dashboard.review.bodyCopy,
            dashboard.adjustPlanCTA.heading,
            dashboard.adjustPlanCTA.bodyCopy
        ]

        parts += dashboard.confidence.improvementActions.map(\.text)
        parts += dashboard.confidence.compactSignals.map { "\($0.label) \($0.value)" }
        parts += dashboard.assumptions.rows.map { "\($0.label) \($0.value)" }
        parts += dashboard.adjustmentRules.rules.map(\.text)
        parts += dashboard.explanation.energyLines.map { "\($0.label) \($0.value)" }

        if let hint = dashboard.review.weighInHint { parts.append(hint) }
        if let note = dashboard.adjustmentRules.aggressivePlanNote { parts.append(note) }
        if let trend = dashboard.adjustmentRules.trendHint { parts.append(trend) }

        return parts.joined(separator: " ")
    }
}
