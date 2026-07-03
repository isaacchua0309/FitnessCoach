//
//  JourneyChapterBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyChapterBuilderTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    // Wednesday, 15 Nov 2023
    private let asOf = Date(timeIntervalSince1970: 1_700_044_800)

    func testNewUserStartsChapterOne() {
        let state = build(maturityLogs: [], allWeights: [])

        XCTAssertEqual(state.chapterNumber, 1)
        XCTAssertEqual(state.chapterTitle, FormaProductCopy.Journey.Chapters.title(for: 1))
        XCTAssertEqual(
            state.nextUnlockLabel,
            FormaProductCopy.Journey.Chapters.nextUnlock(
                FormaProductCopy.Journey.Chapters.title(for: 2)
            )
        )
        XCTAssertEqual(state.totalXP, 0)
        XCTAssertEqual(state.progressPercent, 0)
    }

    func testLogsIncreaseProgress() {
        let empty = build(maturityLogs: [])
        let logs = (0..<3).map { offset in
            makeLog(
                date: calendar.date(byAdding: .day, value: -offset, to: asOf)!,
                calories: 1_800,
                protein: 140,
                waterMl: 2_500
            )
        }
        let logged = build(maturityLogs: logs)

        XCTAssertGreaterThan(logged.totalXP, empty.totalXP)
        XCTAssertGreaterThan(logged.progressPercent, empty.progressPercent)
    }

    func testMilestonesIncreaseProgress() {
        let logs = [makeLog(date: asOf, calories: 1_800, protein: 140, waterMl: 2_500)]

        let withoutMilestones = build(maturityLogs: logs, unlockedMilestoneCount: 0)
        let withMilestones = build(maturityLogs: logs, unlockedMilestoneCount: 2)

        XCTAssertEqual(
            withMilestones.totalXP - withoutMilestones.totalXP,
            JourneyChapterBuilder.milestoneXP(input: buildInput(unlockedMilestoneCount: 2))
        )
    }

    func testChapterAdvancesAfterThreshold() {
        let chapterTwo = JourneyChapterBuilder.chapterProgress(totalXP: 200)
        XCTAssertEqual(chapterTwo.chapter, 2)
        XCTAssertEqual(chapterTwo.xpInChapter, 0)

        let chapterThree = JourneyChapterBuilder.chapterProgress(totalXP: 450)
        XCTAssertEqual(chapterThree.chapter, 3)
        XCTAssertEqual(chapterThree.xpInChapter, 50)
    }

    func testNoNegativeXPOrDuplicateXP() {
        let day = calendar.startOfDay(for: asOf)
        let older = makeLog(date: day, calories: 1_200, protein: 60, waterMl: 500)
        var newer = older
        newer.totals = MacroTotals(calories: 1_900, protein: 140, carbs: 100, fat: 40)
        newer.updatedAt = calendar.date(byAdding: .hour, value: 2, to: day)!

        let duplicateDayXP = JourneyChapterBuilder.dailyBehaviorXP(
            input: buildInput(maturityLogs: [older, newer])
        )
        XCTAssertEqual(duplicateDayXP, 25)

        let weights = (0..<3).map { offset in
            makeWeight(
                date: calendar.date(byAdding: .day, value: -offset, to: asOf)!,
                kg: 80 - Double(offset) * 0.1
            )
        }
        XCTAssertEqual(
            JourneyChapterBuilder.weightXP(input: buildInput(allWeights: weights)),
            10
        )

        XCTAssertGreaterThanOrEqual(
            JourneyChapterBuilder.computeTotalXP(input: buildInput()),
            0
        )
    }

    func testCompletedWeekXPCountsOncePerWeek() {
        let logs = (0..<5).map { offset in
            makeLog(
                date: calendar.date(byAdding: .day, value: -offset, to: asOf)!,
                calories: 1_800,
                protein: 140,
                waterMl: 2_500
            )
        }

        let xp = JourneyChapterBuilder.completedWeekXP(input: buildInput(maturityLogs: logs))
        XCTAssertEqual(xp, 20)
    }

    func testChapterPresentationHidesRawXP() {
        let state = build(
            maturityLogs: [makeLog(date: asOf, calories: 1_800, protein: 140, waterMl: 2_500)],
            unlockedMilestoneCount: 1
        )

        XCTAssertFalse(state.accessibilitySummary.localizedCaseInsensitiveContains("xp"))
        XCTAssertEqual(state.sectionTitle, FormaProductCopy.Journey.Chapters.sectionTitle)
    }

    // MARK: - Helpers

    private func build(
        maturityLogs: [DailyLog],
        allWeights: [WeightEntry] = [],
        healthWorkoutDayStarts: Set<Date> = [],
        isAppleHealthConnected: Bool = false,
        unlockedMilestoneCount: Int = 0
    ) -> JourneyChapterState {
        JourneyChapterBuilder.build(
            buildInput(
                maturityLogs: maturityLogs,
                allWeights: allWeights,
                healthWorkoutDayStarts: healthWorkoutDayStarts,
                isAppleHealthConnected: isAppleHealthConnected,
                unlockedMilestoneCount: unlockedMilestoneCount
            )
        )
    }

    private func buildInput(
        maturityLogs: [DailyLog] = [],
        allWeights: [WeightEntry] = [],
        healthWorkoutDayStarts: Set<Date> = [],
        isAppleHealthConnected: Bool = false,
        unlockedMilestoneCount: Int = 0
    ) -> JourneyChapterBuilder.Input {
        JourneyChapterBuilder.Input(
            maturityLogs: maturityLogs,
            allWeights: allWeights,
            healthWorkoutDayStarts: healthWorkoutDayStarts,
            isAppleHealthConnected: isAppleHealthConnected,
            unlockedMilestoneCount: unlockedMilestoneCount,
            calendar: calendar
        )
    }

    private func makeLog(
        date: Date,
        calories: Int,
        protein: Double,
        waterMl: Int
    ) -> DailyLog {
        DailyLog(
            id: UUID(),
            date: date,
            weightKg: nil,
            targets: UserTargets(
                calorieTarget: 2_000,
                proteinTarget: 120,
                carbTarget: 200,
                fatTarget: 60,
                waterTargetMl: 2_000,
                expectedWeeklyWeightLossKg: 0.5,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(calories: calories, protein: protein, carbs: 100, fat: 40),
            waterConsumedMl: waterMl,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: date,
            updatedAt: date
        )
    }

    private func makeWeight(date: Date, kg: Double) -> WeightEntry {
        WeightEntry(
            id: UUID(),
            date: date,
            weightKg: kg,
            note: nil,
            createdAt: date
        )
    }
}
