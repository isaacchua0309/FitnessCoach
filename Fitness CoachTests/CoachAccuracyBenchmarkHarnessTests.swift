//
//  CoachAccuracyBenchmarkHarnessTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachAccuracyBenchmarkHarnessTests: XCTestCase {

    private var fixture: CoachAccuracyBenchmarkFixtureFile!

    override func setUpWithError() throws {
        fixture = try CoachAccuracyBenchmarkSupport.loadFixture()
    }

    func testLoadsBenchmarkFixtureWithExpectedCategories() {
        XCTAssertEqual(fixture.version, 1)
        XCTAssertGreaterThanOrEqual(fixture.cases.count, 35)
        XCTAssertEqual(fixture.caseCount, fixture.cases.count)
        XCTAssertTrue(fixture.categories.contains("singapore_hawker"))
        XCTAssertTrue(fixture.categories.contains("photo_scenario"))
        XCTAssertTrue(fixture.categories.contains("correction_flow"))
    }

    func testBenchmarkCaseIdsAreUnique() {
        let ids = fixture.cases.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testAllBenchmarkCasesHaveValidMetadata() {
        for benchmarkCase in fixture.cases {
            XCTAssertEqual(
                CoachAccuracyBenchmarkSupport.validateCaseShape(benchmarkCase),
                []
            )
            XCTAssertFalse(benchmarkCase.shouldLogAutomatically)
            XCTAssertTrue(benchmarkCase.shouldRequireConfirmation)
        }
    }

    func testDeterministicBenchmarkPassesAllCases() {
        let summary = CoachAccuracyBenchmarkSupport.runDeterministicBenchmark(fixture: fixture)
        XCTAssertEqual(summary.failedCases, 0, summary.results
            .filter { !$0.passed }
            .map { "\($0.id): \($0.failures.map(\.message).joined(separator: ", "))" }
            .joined(separator: "\n"))
        XCTAssertEqual(summary.passedCases, summary.totalCases)
    }

    func testIncludesRequestedHawkerScenarios() {
        let prompts = fixture.cases
            .filter { $0.category == "singapore_hawker" }
            .map { $0.prompt.lowercased() }
        let phrases = [
            "chicken rice", "nasi lemak", "char kway teow", "laksa", "bak chor mee",
            "duck rice", "caifan", "mala", "yong tau foo", "curry rice", "fish soup", "prata"
        ]
        for phrase in phrases {
            XCTAssertTrue(
                prompts.contains { $0.contains(phrase) },
                "Missing hawker scenario containing '\(phrase)'"
            )
        }
    }

    func testLiveBenchmarkDisabledByDefault() {
        if ProcessInfo.processInfo.environment["RUN_LIVE_FOOD_BENCHMARK"] == "1" {
            XCTAssertTrue(CoachAccuracyBenchmarkSupport.isLiveBenchmarkEnabled())
        } else {
            XCTAssertFalse(CoachAccuracyBenchmarkSupport.isLiveBenchmarkEnabled())
        }
    }
}
