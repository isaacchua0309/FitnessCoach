//
//  SingaporeFoodEstimationFixtureTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class SingaporeFoodEstimationFixtureTests: XCTestCase {

    private var fixture: SingaporeFoodEstimationFixtureFile!

    override func setUpWithError() throws {
        fixture = try SingaporeFoodEstimationFixtureSupport.loadFixture()
    }

    func testLoadsAtLeastFiftyCases() {
        XCTAssertEqual(fixture.version, 1)
        XCTAssertGreaterThanOrEqual(fixture.cases.count, 50)
        XCTAssertEqual(fixture.caseCount, fixture.cases.count)
    }

    func testCaseIdsAreUnique() {
        let ids = fixture.cases.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testAllCasesHaveValidMetadata() {
        for fixtureCase in fixture.cases {
            XCTAssertEqual(
                SingaporeFoodEstimationFixtureSupport.validateFixtureCaseShape(fixtureCase),
                []
            )
            XCTAssertTrue(fixtureCase.shouldRequireConfirmation)
            XCTAssertFalse(fixtureCase.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testReferenceMealsSatisfyRangeHelpers() {
        for fixtureCase in fixture.cases {
            let meal = SingaporeFoodEstimationFixtureSupport.buildReferenceMeal(from: fixtureCase)
            let result = SingaporeFoodEstimationFixtureSupport.validateMealAgainstFixture(
                meal,
                fixtureCase: fixtureCase
            )
            XCTAssertTrue(result.ok, "Fixture \(fixtureCase.id) failed: \(result.errors)")
        }
    }

    func testCompoundPromptAnalysisAlignsWithFixtures() {
        for fixtureCase in fixture.cases {
            let analysis = FoodCompoundDishDetector.analyze(prompt: fixtureCase.inputText)
            let lower = fixtureCase.inputText.lowercased()
            if lower.contains("no rice") || lower.contains("egg only") {
                continue
            }
            if analysis.minRequiredComponents > fixtureCase.expectedComponents.count {
                XCTFail(
                    "\(fixtureCase.id) expects \(analysis.minRequiredComponents) components " +
                    "but fixture lists \(fixtureCase.expectedComponents.count)."
                )
            }
        }
    }

    func testRangeHelpersDoNotRequireExactValues() {
        XCTAssertTrue(SingaporeFoodEstimationFixtureSupport.valueInRange(520, range: MacroRange([450, 750])))
        XCTAssertFalse(SingaporeFoodEstimationFixtureSupport.valueInRange(820, range: MacroRange([450, 750])))
        XCTAssertEqual(SingaporeFoodEstimationFixtureSupport.midpoint(MacroRange([450, 750])), 600)
    }

    func testIncludesRequestedSingaporeAndLocalFoodScenarios() {
        let texts = fixture.cases.map { $0.inputText.lowercased() }
        let phrases = [
            "chicken rice", "roasted chicken rice", "steamed chicken rice", "char siew rice",
            "cai fan", "nasi lemak", "fish soup", "ban mian", "yong tau foo", "mala",
            "economic bee hoon", "prata", "kaya toast", "kopi", "teh", "bubble tea",
            "sushi", "sashimi", "ramen", "udon", "mcspicy", "mcdonald", "subway",
            "protein shake", "greek yogurt", "200g cooked chicken breast", "300g cooked chicken breast",
            "half bowl rice", "one bowl rice", "mixed rice", "bibimbap", "curry rice",
            "gyudon", "poke bowl", "caesar salad", "egg yolks", "tiramisu", "breadtalk", "luckin",
        ]
        for phrase in phrases {
            XCTAssertTrue(texts.contains(where: { $0.contains(phrase) }), "Missing scenario containing '\(phrase)'")
        }
    }

    func testChickenRiceFixtureExpectsDecomposition() {
        let chickenRice = try XCTUnwrap(fixture.cases.first { $0.id == "sg_01_chicken_rice" })
        XCTAssertTrue(chickenRice.expectedComponents.contains("rice"))
        XCTAssertTrue(chickenRice.expectedComponents.contains("chicken"))
        let analysis = FoodCompoundDishDetector.analyze(prompt: chickenRice.inputText)
        XCTAssertGreaterThanOrEqual(analysis.minRequiredComponents, 3)
    }
}
