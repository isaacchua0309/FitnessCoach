//
//  PlanGoalSelectionBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Edit Plan goal selection presentation tests.
//

import XCTest
@testable import Fitness_Coach

final class PlanGoalSelectionBuilderTests: XCTestCase {

    func testOptionsIncludeAllGoalTypes() {
        let options = PlanGoalSelectionBuilder.options(recommendedGoal: .maintain)

        XCTAssertEqual(options.count, PlanGoalType.allCases.count)
        XCTAssertEqual(Set(options.map(\.goalType)), Set(PlanGoalType.allCases))
    }

    func testRecommendedBadgeOnlyOnMatchingGoal() {
        let options = PlanGoalSelectionBuilder.options(recommendedGoal: .gainMuscle)

        XCTAssertTrue(options.first { $0.goalType == .gainMuscle }?.isRecommended == true)
        XCTAssertFalse(options.first { $0.goalType == .loseFat }?.isRecommended == true)
        XCTAssertFalse(options.first { $0.goalType == .maintain }?.isRecommended == true)
    }

    func testRecommendedGoalFollowsProfileWeights() {
        XCTAssertEqual(
            PlanGoalSelectionBuilder.recommendedGoal(for: PlanMissionControlFixtures.loseProfile),
            .loseFat
        )
        XCTAssertEqual(
            PlanGoalSelectionBuilder.recommendedGoal(for: PlanMissionControlFixtures.maintainProfile),
            .maintain
        )
        XCTAssertEqual(
            PlanGoalSelectionBuilder.recommendedGoal(for: PlanMissionControlFixtures.gainProfile),
            .gainMuscle
        )
    }

    func testCopyUsesFriendlyLabelsNotRawEnumIDs() {
        let options = PlanGoalSelectionBuilder.options(recommendedGoal: .loseFat)

        for option in options {
            XCTAssertFalse(option.title.contains("loseFat"))
            XCTAssertFalse(option.title.contains("gainMuscle"))
            XCTAssertFalse(option.explanation.isEmpty)
            XCTAssertFalse(option.outcomePreview.isEmpty)
            XCTAssertFalse(option.iconSystemName.isEmpty)
        }

        let loseFat = try XCTUnwrap(options.first { $0.goalType == .loseFat })
        XCTAssertEqual(loseFat.explanation, FormaProductCopy.PlanEditGoal.loseFatExplanation)
        XCTAssertEqual(loseFat.outcomePreview, FormaProductCopy.PlanEditGoal.loseFatOutcome)
    }
}
