//
//  PlanHealthIntelligencePresentationBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanHealthIntelligencePresentationBuilderTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private var referenceDay: Date {
        calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 8))!
        )
    }

    func testStrongSignalsMapsLoadedSection() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: makeStrongInput(),
            calendar: calendar
        )

        XCTAssertEqual(section.confidenceCard.phase, .loaded)
        XCTAssertEqual(section.confidenceCard.confidenceLabel, FormaProductCopy.PlanHealthIntelligencePresentation.confidenceModerate)
        XCTAssertFalse(section.assumptions.items.isEmpty)
        XCTAssertTrue(section.dataQuality.signals.contains { $0.kind == .recoveryTrend })
        XCTAssertTrue(section.dataQuality.signals.contains { $0.kind == .averageSteps })
        XCTAssertTrue(section.dataQuality.signals.contains { $0.kind == .trainingFrequency })
        XCTAssertTrue(section.dataQuality.signals.contains { $0.kind == .workoutConsistency })
        XCTAssertTrue(section.missingDataActions.isEmpty)
        XCTAssertTrue(section.confidenceCard.summary.contains("workable"))
        XCTAssertTrue(section.confidenceCard.disclaimerLine.contains("not a medical"))
    }

    func testSparseSignalsShowMissingActionsAndLimitedAssumptions() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: makeSparseInput(),
            calendar: calendar
        )

        XCTAssertEqual(section.confidenceCard.confidenceLabel, FormaProductCopy.PlanHealthIntelligencePresentation.confidenceLow)
        XCTAssertTrue(section.assumptions.items.contains { $0.isLimited })
        XCTAssertTrue(section.dataQuality.signals.contains { $0.kind == .sleep && $0.status != .available })
        XCTAssertTrue(section.dataQuality.signals.contains { $0.kind == .heartVariability && $0.status != .available })
        XCTAssertTrue(section.missingDataActions.contains { $0.id == "weight" })
        XCTAssertTrue(section.missingDataActions.contains { $0.id == "nutrition" })
        XCTAssertTrue(section.missingDataActions.contains { $0.id == "sleep" })
    }

    func testUnknownConfidenceUsesEmptyCardWhenNoSignals() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: PlanHealthIntelligenceBuildInput(
                planConfidence: .unknown,
                baselineContext: .empty(for: referenceDay),
                recovery: .unknown,
                hasNutritionLogging: false,
                hasRecentWeightLog: false
            ),
            calendar: calendar
        )

        XCTAssertEqual(section.confidenceCard.phase, .empty)
        XCTAssertTrue(section.missingDataActions.contains { $0.id == "connect-health" })
    }

    func testBuildInputFromSnapshotMapsPlanConfidenceAndRecovery() {
        let snapshot = HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: makeRecovery(score: 68, status: .moderate),
            workout: nil,
            activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 35),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.75, label: "Moderate"),
            nextBestAction: .none
        )

        let input = PlanHealthIntelligenceBuildInput.from(
            snapshot: snapshot,
            baselineContext: makeStrongBaseline(),
            hasNutritionLogging: true,
            hasRecentWeightLog: true
        )

        XCTAssertEqual(input.planConfidence.label, "Moderate")
        XCTAssertEqual(input.recovery?.score, 68)
    }

    func testCopyAvoidsMedicalPrecisionLanguage() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: makeSparseInput(),
            calendar: calendar
        )

        let combined = [
            section.confidenceCard.headline,
            section.confidenceCard.summary,
            section.confidenceCard.disclaimerLine,
            section.assumptions.summary
        ].joined(separator: " ").lowercased()

        XCTAssertFalse(combined.contains("diagnosis"))
        XCTAssertFalse(combined.contains("clinical"))
        XCTAssertTrue(combined.contains("not a medical"))
    }

    func testCodableRoundTripForSectionState() throws {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: makeStrongInput(),
            calendar: calendar
        )

        let data = try JSONEncoder().encode(section)
        let decoded = try JSONDecoder().decode(PlanHealthIntelligenceSectionState.self, from: data)

        XCTAssertEqual(decoded, section)
    }

    func testLoadingSectionUsesLoadingConfidenceCard() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: PlanHealthIntelligenceBuildInput(isLoading: true),
            calendar: calendar
        )

        XCTAssertTrue(section.isLoading)
        XCTAssertEqual(section.confidenceCard.phase, .loading)
        XCTAssertTrue(section.assumptions.items.isEmpty)
    }

    // MARK: - Fixtures

    private func makeStrongInput() -> PlanHealthIntelligenceBuildInput {
        PlanHealthIntelligenceBuildInput(
            planConfidence: PlanHealthConfidence(score: 0.78, label: "Moderate"),
            baselineContext: makeStrongBaseline(),
            recovery: makeRecovery(score: 74, status: .moderate),
            hasNutritionLogging: true,
            hasRecentWeightLog: true
        )
    }

    private func makeSparseInput() -> PlanHealthIntelligenceBuildInput {
        PlanHealthIntelligenceBuildInput(
            planConfidence: PlanHealthConfidence(score: 0.42, label: "Limited"),
            baselineContext: makeSparseBaseline(),
            recovery: .unknown,
            hasNutritionLogging: false,
            hasRecentWeightLog: false
        )
    }

    private func makeStrongBaseline() -> HealthBaselineContext {
        HealthBaselineContext(
            targetDate: referenceDay,
            averageSteps7d: 8_450,
            averageSteps28d: 7_900,
            averageActiveEnergy7d: 420,
            averageActiveEnergy28d: 390,
            averageSleepDuration7d: 426,
            averageSleepDuration28d: 408,
            averageRestingHeartRate28d: 58,
            averageHRV28d: 52,
            averageWorkoutLoad28d: 180,
            workoutDays7d: 4,
            workoutDays28d: 12,
            availableSignals: [.steps, .activeEnergy, .sleep, .restingHeartRate, .hrv, .workoutLoad],
            missingSignals: []
        )
    }

    private func makeSparseBaseline() -> HealthBaselineContext {
        HealthBaselineContext(
            targetDate: referenceDay,
            averageSteps7d: 5_200,
            averageSteps28d: nil,
            averageActiveEnergy7d: nil,
            averageActiveEnergy28d: nil,
            averageSleepDuration7d: nil,
            averageSleepDuration28d: nil,
            averageRestingHeartRate28d: nil,
            averageHRV28d: nil,
            averageWorkoutLoad28d: nil,
            workoutDays7d: 1,
            workoutDays28d: 2,
            availableSignals: [.steps, .workoutLoad],
            missingSignals: [.sleep, .hrv, .restingHeartRate, .activeEnergy]
        )
    }

    private func makeRecovery(score: Int, status: RecoveryStatus) -> RecoverySummary {
        RecoverySummary(
            score: score,
            status: status,
            title: "Recovery",
            explanation: "Explanation",
            recommendedTraining: "Train based on feel.",
            recommendedNutrition: "Stay on plan.",
            confidence: .moderate,
            contributingFactors: [],
            missingSignals: []
        )
    }
}
