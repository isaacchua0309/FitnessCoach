//
//  WeeklyReviewServiceTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class WeeklyReviewServiceTests: XCTestCase {

    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()
        calendar = WeeklyReviewServiceTestSupport.makeCalendar()
        referenceDate = WeeklyReviewServiceTestSupport.day(2026, 7, 8, hour: 12, calendar: calendar)
    }

    func testCompletedWeekGeneration() async {
        let completedWeekStart = WeeklyReviewServiceTestSupport.day(2026, 6, 29, calendar: calendar)
        let completedWeekEnd = WeeklyReviewServiceTestSupport.day(2026, 7, 5, calendar: calendar)
        let harness = WeeklyReviewServiceTestSupport.makeHarness(
            referenceDate: referenceDate,
            calendar: calendar
        )
        harness.seedCompletedWeek(weekEnd: completedWeekEnd)

        let review = await harness.service.generateWeeklyReview(
            for: completedWeekStart,
            forceRefresh: false,
            allowPreview: false,
            calendar: calendar
        )

        XCTAssertNotNil(review)
        XCTAssertEqual(review?.stats.totalWorkouts, 3)
        XCTAssertTrue(review?.wins.isEmpty == false)
        XCTAssertNotNil(harness.cacheStore.weeklyReview(for: completedWeekStart, calendar: calendar))
    }

    func testCurrentWeekPreviewDoesNotOverwriteCompletedReview() async {
        let completedWeekStart = WeeklyReviewServiceTestSupport.day(2026, 6, 29, calendar: calendar)
        let completedWeekEnd = WeeklyReviewServiceTestSupport.day(2026, 7, 5, calendar: calendar)
        let currentWeekStart = WeeklyReviewServiceTestSupport.day(2026, 7, 6, calendar: calendar)
        let harness = WeeklyReviewServiceTestSupport.makeHarness(
            referenceDate: referenceDate,
            calendar: calendar
        )
        harness.seedCompletedWeek(weekEnd: completedWeekEnd)
        harness.seedCurrentWeekPartial(weekEnd: WeeklyReviewServiceTestSupport.day(2026, 7, 8, calendar: calendar))

        let completed = await harness.service.generateWeeklyReview(
            for: completedWeekStart,
            forceRefresh: false,
            allowPreview: false,
            calendar: calendar
        )
        XCTAssertNotNil(completed)

        let cachedBeforePreview = harness.cacheStore.weeklyReview(for: completedWeekStart, calendar: calendar)
        XCTAssertNotNil(cachedBeforePreview)

        let preview = await harness.service.generateWeeklyReview(
            for: currentWeekStart,
            forceRefresh: false,
            allowPreview: true,
            calendar: calendar
        )
        XCTAssertNotNil(preview)

        let cachedAfterPreview = harness.cacheStore.weeklyReview(for: completedWeekStart, calendar: calendar)
        XCTAssertEqual(cachedAfterPreview?.generatedAt, cachedBeforePreview?.generatedAt)
        XCTAssertNil(harness.cacheStore.weeklyReview(for: currentWeekStart, calendar: calendar))
    }

    func testCacheHitAvoidsRegeneration() async {
        let completedWeekStart = WeeklyReviewServiceTestSupport.day(2026, 6, 29, calendar: calendar)
        let completedWeekEnd = WeeklyReviewServiceTestSupport.day(2026, 7, 5, calendar: calendar)
        let harness = WeeklyReviewServiceTestSupport.makeHarness(
            referenceDate: referenceDate,
            calendar: calendar
        )
        harness.seedCompletedWeek(weekEnd: completedWeekEnd)

        let first = await harness.service.generateWeeklyReview(
            for: completedWeekStart,
            forceRefresh: false,
            allowPreview: false,
            calendar: calendar
        )
        let evaluateCountAfterFirst = harness.countingEngine.evaluateCount

        let second = await harness.service.generateWeeklyReview(
            for: completedWeekStart,
            forceRefresh: false,
            allowPreview: false,
            calendar: calendar
        )

        XCTAssertEqual(first?.generatedAt, second?.generatedAt)
        XCTAssertEqual(harness.countingEngine.evaluateCount, evaluateCountAfterFirst)
    }

    func testForceRefreshUpdatesGeneratedAt() async {
        let completedWeekStart = WeeklyReviewServiceTestSupport.day(2026, 6, 29, calendar: calendar)
        let completedWeekEnd = WeeklyReviewServiceTestSupport.day(2026, 7, 5, calendar: calendar)
        let harness = WeeklyReviewServiceTestSupport.makeHarness(
            referenceDate: referenceDate,
            calendar: calendar
        )
        harness.seedCompletedWeek(weekEnd: completedWeekEnd)

        let first = await harness.service.generateWeeklyReview(
            for: completedWeekStart,
            forceRefresh: false,
            allowPreview: false,
            calendar: calendar
        )
        XCTAssertNotNil(first)

        harness.clock.advance(by: 3_600)
        harness.countingEngine.evaluateCount = 0

        let refreshed = await harness.service.generateWeeklyReview(
            for: completedWeekStart,
            forceRefresh: true,
            allowPreview: false,
            calendar: calendar
        )

        XCTAssertNotNil(refreshed)
        XCTAssertGreaterThan(refreshed?.generatedAt ?? .distantPast, first?.generatedAt ?? .distantFuture)
        XCTAssertGreaterThan(harness.countingEngine.evaluateCount, 0)
        XCTAssertEqual(
            refreshed?.generatedAt,
            harness.cacheStore.weeklyReview(for: completedWeekStart, calendar: calendar)?.generatedAt
        )
    }

    func testSparseDataReviewStillGenerates() async {
        let completedWeekStart = WeeklyReviewServiceTestSupport.day(2026, 6, 29, calendar: calendar)
        let completedWeekEnd = WeeklyReviewServiceTestSupport.day(2026, 7, 5, calendar: calendar)
        let harness = WeeklyReviewServiceTestSupport.makeHarness(
            referenceDate: referenceDate,
            calendar: calendar
        )
        harness.seedSparseCompletedWeek(weekEnd: completedWeekEnd)

        let review = await harness.service.generateWeeklyReview(
            for: completedWeekStart,
            forceRefresh: false,
            allowPreview: false,
            calendar: calendar
        )

        XCTAssertNotNil(review)
        XCTAssertEqual(review?.confidence, .low)
        XCTAssertTrue(review?.missingSignals.contains(.nutrition) == true)
    }

    func testMissingProvidersDoNotCrash() async {
        let completedWeekStart = WeeklyReviewServiceTestSupport.day(2026, 6, 29, calendar: calendar)
        let completedWeekEnd = WeeklyReviewServiceTestSupport.day(2026, 7, 5, calendar: calendar)
        let harness = WeeklyReviewServiceTestSupport.makeHarness(
            referenceDate: referenceDate,
            calendar: calendar,
            nutritionProvider: EmptyHealthIntelligenceNutritionProvider(),
            weightProvider: EmptyHealthIntelligenceWeightProvider(),
            userPlanProvider: EmptyHealthIntelligenceUserPlanProvider()
        )
        harness.seedCompletedWeek(weekEnd: completedWeekEnd)

        let review = await harness.service.generateWeeklyReview(
            for: completedWeekStart,
            forceRefresh: false,
            allowPreview: false,
            calendar: calendar
        )

        XCTAssertNotNil(review)
    }

    func testGetLatestCompletedWeeklyReviewReturnsCachedWeek() async {
        let completedWeekStart = WeeklyReviewServiceTestSupport.day(2026, 6, 29, calendar: calendar)
        let completedWeekEnd = WeeklyReviewServiceTestSupport.day(2026, 7, 5, calendar: calendar)
        let harness = WeeklyReviewServiceTestSupport.makeHarness(
            referenceDate: referenceDate,
            calendar: calendar
        )
        harness.seedCompletedWeek(weekEnd: completedWeekEnd)

        _ = await harness.service.generateWeeklyReview(
            for: completedWeekStart,
            forceRefresh: false,
            allowPreview: false,
            calendar: calendar
        )

        let latest = await harness.service.getLatestCompletedWeeklyReview(calendar: calendar)

        XCTAssertNotNil(latest)
        XCTAssertTrue(
            WeeklyReviewWeekPolicy.weekStartMatches(
                latest!,
                weekStart: completedWeekStart,
                calendar: calendar
            )
        )
    }

    func testIncompleteWeekWithoutPreviewReturnsNil() async {
        let currentWeekStart = WeeklyReviewServiceTestSupport.day(2026, 7, 6, calendar: calendar)
        let harness = WeeklyReviewServiceTestSupport.makeHarness(
            referenceDate: referenceDate,
            calendar: calendar
        )
        harness.seedCurrentWeekPartial(weekEnd: referenceDate)

        let review = await harness.service.getWeeklyReview(for: currentWeekStart, calendar: calendar)

        XCTAssertNil(review)
    }
}

// MARK: - Test support

private enum WeeklyReviewServiceTestSupport {

    static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }

    static func day(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        calendar: Calendar = makeCalendar()
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    static func makeHarness(
        referenceDate: Date,
        calendar: Calendar,
        nutritionProvider: (any HealthIntelligenceNutritionProviding)? = nil,
        weightProvider: (any HealthIntelligenceWeightProviding)? = nil,
        userPlanProvider: (any HealthIntelligenceUserPlanProviding)? = nil
    ) -> WeeklyReviewServiceTestHarness {
        WeeklyReviewServiceTestHarness(
            referenceDate: referenceDate,
            calendar: calendar,
            nutritionProvider: nutritionProvider,
            weightProvider: weightProvider,
            userPlanProvider: userPlanProvider
        )
    }
}

private final class WeeklyReviewServiceTestHarness {

    let calendar: Calendar
    let repository: PipelineMockRepository
    let nutritionProvider: PipelineMockNutritionProvider
    let weightProvider: PipelineMockWeightProvider
    let userPlanProvider: PipelineMockUserPlanProvider
    let cacheStore: MemoryHealthCacheStore
    let countingEngine: CountingWeeklyReviewEngine
    let clock: MutableTestClock
    let service: WeeklyReviewService

    init(
        referenceDate: Date,
        calendar: Calendar,
        nutritionProvider: (any HealthIntelligenceNutritionProviding)? = nil,
        weightProvider: (any HealthIntelligenceWeightProviding)? = nil,
        userPlanProvider: (any HealthIntelligenceUserPlanProviding)? = nil
    ) {
        self.calendar = calendar
        self.repository = PipelineMockRepository(calendar: calendar)
        self.nutritionProvider = PipelineMockNutritionProvider()
        self.weightProvider = PipelineMockWeightProvider()
        self.userPlanProvider = PipelineMockUserPlanProvider()
        self.cacheStore = MemoryHealthCacheStore()
        self.countingEngine = CountingWeeklyReviewEngine()
        self.clock = MutableTestClock(now: referenceDate, calendar: calendar)

        let resolvedNutrition = nutritionProvider ?? self.nutritionProvider
        let resolvedWeight = weightProvider ?? self.weightProvider
        let resolvedUserPlan = userPlanProvider ?? self.userPlanProvider

        let contextBuilder = HealthIntelligenceContextBuilder(
            repository: repository,
            nutritionProvider: resolvedNutrition,
            weightProvider: resolvedWeight,
            userPlanProvider: resolvedUserPlan,
            clock: clock
        )

        self.service = WeeklyReviewService(
            contextBuilder: contextBuilder,
            weeklyReviewEngine: countingEngine,
            recoveryEngine: RecoveryEngine(),
            trainingLoadEngine: TrainingLoadEngine(),
            cacheStore: cacheStore,
            clock: clock,
            enginesEnabled: true
        )

        if userPlanProvider == nil {
            self.userPlanProvider.plan = HealthIntelligencePipelineFixtures.defaultPlan()
        }
    }

    func seedCompletedWeek(weekEnd: Date) {
        HealthIntelligencePipelineFixtures.seedDailyMetrics(
            into: repository,
            endingOn: weekEnd,
            days: 7,
            steps: 8_500,
            calendar: calendar
        )
        HealthIntelligencePipelineFixtures.seedNutritionWeek(
            into: nutritionProvider,
            endingOn: weekEnd,
            calendar: calendar
        )
        repository.workouts = [
            HealthIntelligencePipelineFixtures.makeWorkout(
                on: calendar.date(byAdding: .day, value: -2, to: weekEnd)!,
                duration: 40,
                calendar: calendar
            ),
            HealthIntelligencePipelineFixtures.makeWorkout(
                on: calendar.date(byAdding: .day, value: -4, to: weekEnd)!,
                duration: 35,
                calendar: calendar
            ),
            HealthIntelligencePipelineFixtures.makeWorkout(
                on: weekEnd,
                duration: 45,
                calendar: calendar
            )
        ]
        HealthIntelligencePipelineFixtures.seedHeartBaselines(
            into: repository,
            endingOn: weekEnd,
            calendar: calendar
        )
    }

    func seedCurrentWeekPartial(weekEnd: Date) {
        HealthIntelligencePipelineFixtures.seedDailyMetrics(
            into: repository,
            endingOn: weekEnd,
            days: 7,
            steps: 6_000,
            calendar: calendar
        )
    }

    func seedSparseCompletedWeek(weekEnd: Date) {
        HealthIntelligencePipelineFixtures.seedDailyMetrics(
            into: repository,
            endingOn: weekEnd,
            days: 7,
            steps: 4_500,
            calendar: calendar
        )
    }
}

private final class CountingWeeklyReviewEngine: WeeklyReviewProviding, @unchecked Sendable {
    private let engine = WeeklyReviewEngine()
    var evaluateCount = 0

    func evaluate(_ input: WeeklyReviewEngineInput) throws -> WeeklyHealthReview? {
        evaluateCount += 1
        return try engine.evaluate(input)
    }
}

private final class MutableTestClock: HealthIntelligenceClockProviding, @unchecked Sendable {
    private var nowValue: Date
    private let calendarValue: Calendar
    private let lock = NSLock()

    init(now: Date, calendar: Calendar) {
        self.nowValue = now
        self.calendarValue = calendar
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return nowValue
    }

    func calendar() -> Calendar { calendarValue }

    func advance(by interval: TimeInterval) {
        lock.lock()
        nowValue = nowValue.addingTimeInterval(interval)
        lock.unlock()
    }
}
