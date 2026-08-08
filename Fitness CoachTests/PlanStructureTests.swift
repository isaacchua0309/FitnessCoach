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
            .weeklyRecommendation,
            .planConfidence,
            .nextReview
        ])
        XCTAssertEqual(PlanProductLayout.sectionOrder.first, .header)
        XCTAssertEqual(PlanProductLayout.sectionOrder.last, .nextReview)
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
        XCTAssertEqual(dashboard.weeklyRecommendation.sectionTitle, "Weekly recommendation")
        XCTAssertEqual(dashboard.confidence.sectionTitle, "Plan Confidence")
        XCTAssertEqual(dashboard.review.sectionTitle, "Next Review")
        // Kept in presentation state for calculation sheet / fixtures, not on scroll:
        XCTAssertEqual(dashboard.status.sectionTitle, "Plan Status")
        XCTAssertEqual(dashboard.explanation.sectionTitle, "Why This Works")
        XCTAssertEqual(dashboard.adjustmentRules.sectionTitle, "When to Adjust")
        XCTAssertEqual(dashboard.assumptions.sectionTitle, "Plan Assumptions")
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
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("plan_status"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("why_this_works"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("when_to_adjust"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("plan_assumptions"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("adjust_plan_cta"))
    }

    func testDashboardStateEmbedsPresentationSectionsNotLegacyProductSections() {
        let state = PlanStateBuilder.dashboardState(profile: PlanMissionControlFixtures.loseProfile)

        XCTAssertEqual(state.strategy.goalDirection, .cut)
        XCTAssertFalse(state.dailyTargets.caloriesLabel.isEmpty)
        XCTAssertFalse(state.assumptions.rows.isEmpty)
        XCTAssertNotNil(state.explanation.calculationDetails)
    }

    func testTrimmedPlanPageOmitsLowROISectionTitlesFromVisibleContract() {
        let forbiddenOnScroll = [
            "Next Milestone",
            "This Week",
            "Activity Assumptions",
            "Complete 7 days of logging",
            "Plan Status",
            "Why This Works",
            "When to Adjust",
            "Plan Assumptions"
        ]

        for dashboard in [
            PlanMissionControlFixtures.loseDashboard,
            PlanMissionControlFixtures.activeUserDashboard,
            PlanMissionControlFixtures.newUserDashboard
        ] {
            let combined = planDashboardVisibleCopy(from: dashboard)

            for title in forbiddenOnScroll {
                XCTAssertFalse(
                    combined.contains(title),
                    "Section title '\(title)' should not appear in trimmed Plan visible contract"
                )
            }

            XCTAssertFalse(
                combined.contains("Current ") && combined.contains("→ Goal "),
                "Legacy progress route summary should not appear on Plan dashboard"
            )
            XCTAssertTrue(combined.contains("Your Strategy"))
            XCTAssertTrue(combined.contains("Daily Targets"))
            XCTAssertTrue(combined.contains("Weekly recommendation"))
            XCTAssertTrue(combined.contains("Plan Confidence"))
            XCTAssertTrue(combined.contains("Next Review"))
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
            dashboard.dailyTargets.caloriesLabel,
            dashboard.dailyTargets.prescriptionCopy,
            dashboard.weeklyRecommendation.sectionTitle,
            dashboard.weeklyRecommendation.safetyCopy,
            dashboard.confidence.sectionTitle,
            dashboard.confidence.scoreHeadline,
            dashboard.review.sectionTitle,
            dashboard.review.headline,
            dashboard.review.bodyCopy
        ]

        if let expectedPaceLabel = dashboard.strategy.expectedPaceLabel,
           let expectedPaceValue = dashboard.strategy.expectedPaceValue {
            parts.append("\(expectedPaceLabel) \(expectedPaceValue)")
        }
        parts.append("\(dashboard.strategy.strategyStatusLabel) \(dashboard.strategy.strategyStatusValue)")
        parts += dashboard.confidence.improvementActions.map(\.text)
        parts += dashboard.confidence.compactSignals.map { "\($0.label) \($0.value)" }

        if let hint = dashboard.review.weighInHint { parts.append(hint) }
        if dashboard.explanation.showsCalculationAction {
            parts.append(dashboard.explanation.seeCalculationTitle)
        }

        return parts.joined(separator: " ")
    }
}
