//
//  PlanEditDifficultyLabelBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Edit Plan difficulty label mapping contract.
//

import XCTest
@testable import Fitness_Coach

final class PlanEditDifficultyLabelBuilderTests: XCTestCase {

    private var copy: FormaProductCopy.PlanEditDifficulty.Type {
        FormaProductCopy.PlanEditDifficulty.self
    }

    func testCutPaceLabelsMapToFriendlyCopy() {
        XCTAssertEqual(
            PlanEditDifficultyLabelBuilder.label(goalDirection: .cut, paceChoice: .gentle),
            copy.gentleCut
        )
        XCTAssertEqual(
            PlanEditDifficultyLabelBuilder.label(goalDirection: .cut, paceChoice: .moderate),
            copy.moderateCut
        )
        XCTAssertEqual(
            PlanEditDifficultyLabelBuilder.label(goalDirection: .cut, paceChoice: .aggressive),
            copy.fasterCut
        )
        XCTAssertEqual(
            PlanEditDifficultyLabelBuilder.label(goalDirection: .cut, paceChoice: .advanced),
            copy.customCut
        )
    }

    func testMaintainAndGainDirectionsUseDedicatedLabels() {
        XCTAssertEqual(
            PlanEditDifficultyLabelBuilder.label(goalDirection: .maintain, paceChoice: .moderate),
            copy.maintenance
        )
        XCTAssertEqual(
            PlanEditDifficultyLabelBuilder.label(goalDirection: .gain, paceChoice: .aggressive),
            copy.leanGain
        )
    }

    func testFasterCutLabelConstantMatchesAggressivePaceLabel() {
        XCTAssertEqual(
            PlanEditDifficultyLabelBuilder.fasterCutLabel,
            copy.fasterCut
        )
        XCTAssertEqual(
            PlanEditDifficultyLabelBuilder.label(goalDirection: .cut, paceChoice: .aggressive),
            PlanEditDifficultyLabelBuilder.fasterCutLabel
        )
    }

    func testAllDifficultyLabelsAvoidRawEnumIDs() {
        let labels = [
            PlanEditDifficultyLabelBuilder.label(goalDirection: .cut, paceChoice: .gentle),
            PlanEditDifficultyLabelBuilder.label(goalDirection: .cut, paceChoice: .moderate),
            PlanEditDifficultyLabelBuilder.label(goalDirection: .cut, paceChoice: .aggressive),
            PlanEditDifficultyLabelBuilder.label(goalDirection: .cut, paceChoice: .advanced),
            PlanEditDifficultyLabelBuilder.label(goalDirection: .maintain, paceChoice: .moderate),
            PlanEditDifficultyLabelBuilder.label(goalDirection: .gain, paceChoice: .moderate)
        ]

        for label in labels {
            XCTAssertFalse(label.contains("loseFat"))
            XCTAssertFalse(label.contains("gainMuscle"))
            XCTAssertFalse(label.contains("aggressiveDeficit"))
            XCTAssertFalse(label.contains("WeightLossPaceChoice"))
        }
    }
}
