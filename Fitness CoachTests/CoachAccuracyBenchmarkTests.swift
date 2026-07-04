//
//  CoachAccuracyBenchmarkTests.swift
//  Fitness CoachTests
//
//  Benchmark harness for Singapore/local food estimation fixtures.
//

import XCTest
@testable import Fitness_Coach

final class CoachAccuracyBenchmarkTests: XCTestCase {

    private var fixture: SingaporeFoodEstimationFixtureFile!

    override func setUpWithError() throws {
        fixture = try SingaporeFoodEstimationFixtureSupport.loadFixture()
    }

    func testBenchmarkPassRateMeetsMinimumThreshold() throws {
        let report = runBenchmark()
        XCTAssertGreaterThanOrEqual(fixture.cases.count, 50)
        XCTAssertGreaterThanOrEqual(report.passRate, 0.95, report.summary)
        XCTAssertEqual(report.totalCases, fixture.cases.count)
    }

    func testBenchmarkReferenceMealsStayWithinFixtureRanges() {
        let report = runBenchmark()
        XCTAssertEqual(report.failedCaseIds.count, 0, report.summary)
        XCTAssertGreaterThan(report.averageCalorieDelta, 0)
    }

    func testBenchmarkIncludesAssumptionAndRangeCoverage() {
        let report = runBenchmark()
        XCTAssertGreaterThan(report.casesWithAssumptions, 0)
        XCTAssertGreaterThan(report.casesWithCalorieRange, 0)
    }

    // MARK: - Harness

    private func runBenchmark() -> CoachAccuracyBenchmarkReport {
        var passed = 0
        var failedCaseIds: [String] = []
        var calorieDeltas: [Double] = []
        var casesWithAssumptions = 0
        var casesWithCalorieRange = 0

        for fixtureCase in fixture.cases {
            let meal = SingaporeFoodEstimationFixtureSupport.buildReferenceMeal(from: fixtureCase)
            let mealWithRange = FoodCalorieRangeResolver.fillMissingRanges(meal)
            let validation = SingaporeFoodEstimationFixtureSupport.validateMealAgainstFixture(
                mealWithRange,
                fixtureCase: fixtureCase
            )

            if !mealWithRange.assumptions.isEmpty || !fixtureCase.expectedAssumptions.isEmpty {
                casesWithAssumptions += 1
            }
            if FoodCalorieRangeResolver.resolvedRange(for: mealWithRange) != nil {
                casesWithCalorieRange += 1
            }

            if validation.ok {
                passed += 1
                let midpoint = SingaporeFoodEstimationFixtureSupport.midpoint(fixtureCase.caloriesRange)
                calorieDeltas.append(abs(Double(mealWithRange.totalCalories) - midpoint))
            } else {
                failedCaseIds.append(fixtureCase.id)
            }
        }

        let total = fixture.cases.count
        return CoachAccuracyBenchmarkReport(
            totalCases: total,
            passedCases: passed,
            failedCaseIds: failedCaseIds,
            passRate: total == 0 ? 0 : Double(passed) / Double(total),
            averageCalorieDelta: calorieDeltas.isEmpty ? 0 : calorieDeltas.reduce(0, +) / Double(calorieDeltas.count),
            casesWithAssumptions: casesWithAssumptions,
            casesWithCalorieRange: casesWithCalorieRange
        )
    }
}

struct CoachAccuracyBenchmarkReport: Equatable {
    let totalCases: Int
    let passedCases: Int
    let failedCaseIds: [String]
    let passRate: Double
    let averageCalorieDelta: Double
    let casesWithAssumptions: Int
    let casesWithCalorieRange: Int

    var summary: String {
        "passRate=\(String(format: "%.2f", passRate)) failed=[\(failedCaseIds.joined(separator: ", "))]"
    }
}
