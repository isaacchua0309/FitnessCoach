//
//  CoachContextCorrectnessValidatorTests.swift
//  Fitness CoachTests
//
//  CoachContextPacketV2 internal consistency validation tests.
//

import XCTest
@testable import Fitness_Coach

final class CoachContextCorrectnessValidatorTests: XCTestCase {

    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        self.calendar = calendar

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 7
        components.day = 3
        components.hour = 14
        components.minute = 30
        referenceDate = calendar.date(from: components)!
    }

    func testValidPacketHasNoIssues() {
        let packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        let result = CoachContextCorrectnessValidator.validateAndCorrect(
            packet,
            calendar: calendar
        )

        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.issues.isEmpty)
    }

    func testCaloriesConsumedMustMatchConfirmedFoodEntries() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.today?.nutrition?.caloriesConsumed = 999

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .caloriesMatchConfirmedFood })
        XCTAssertEqual(result.correctedPacket.today?.nutrition?.caloriesConsumed, 420)
    }

    func testMacrosConsumedCannotBeNegative() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.today?.nutrition?.proteinConsumed = -4
        packet.today?.nutrition?.carbsConsumed = -2
        packet.today?.nutrition?.fatConsumed = -1

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .macrosNonNegative })
        XCTAssertEqual(result.correctedPacket.today?.nutrition?.proteinConsumed, 0)
        XCTAssertEqual(result.correctedPacket.today?.nutrition?.carbsConsumed, 0)
        XCTAssertEqual(result.correctedPacket.today?.nutrition?.fatConsumed, 0)
    }

    func testWaterConsumedCannotBeNegative() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.today?.hydration?.waterConsumedMl = -100

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .waterNonNegative })
        XCTAssertEqual(result.correctedPacket.today?.hydration?.waterConsumedMl, 0)
        XCTAssertEqual(result.correctedPacket.today?.hydration?.waterRemainingMl, 2_500)
    }

    func testRemainingValuesMustMatchTargetMinusConsumed() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.today?.nutrition?.caloriesRemaining = 1
        packet.today?.nutrition?.proteinRemaining = 1
        packet.today?.hydration?.waterRemainingMl = 1

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .remainingValuesConsistent })
        XCTAssertEqual(result.correctedPacket.today?.nutrition?.caloriesRemaining, 1_580)
        XCTAssertEqual(result.correctedPacket.today?.nutrition?.proteinRemaining, 92, accuracy: 0.01)
        XCTAssertEqual(result.correctedPacket.today?.hydration?.waterRemainingMl, 2_500)
    }

    func testPendingRejectedFoodExcludedFromConsumedTotals() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.today?.nutrition?.caloriesConsumed = 800
        packet.recentMealsStructured = []
        packet.timeline = CoachContextTimelinePacket(
            recentEvents: [
                CoachTimelineContextEvent(
                    id: UUID(),
                    timestamp: referenceDate,
                    type: CoachTimelineEventType.foodRejected.rawValue,
                    source: "estimateFood",
                    status: CoachTimelineEventStatus.rejected.rawValue,
                    summary: "Rejected estimate: Burger",
                    compactPayload: ["meal": "Burger"],
                    confidence: .medium,
                    linkedEntryId: nil,
                    linkedMessageId: nil
                )
            ]
        )

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .pendingRejectedNotInTotals })
        XCTAssertEqual(result.correctedPacket.today?.nutrition?.caloriesConsumed, 0)
    }

    func testTimelineEventsMustBeSortedByTimestamp() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        let earlier = referenceDate.addingTimeInterval(-3_600)
        packet.timeline.recentEvents = [
            timelineFoodEvent(at: referenceDate, calories: 420),
            timelineFoodEvent(at: earlier, calories: 200)
        ]

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .timelineSorted })
        XCTAssertEqual(
            result.correctedPacket.timeline.recentEvents.map(\.timestamp),
            [earlier, referenceDate]
        )
    }

    func testLocalDateMustMatchTimezoneConversion() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.meta.localDate = "2020-01-01"

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .localDateTimezoneConsistent })
        XCTAssertEqual(result.correctedPacket.meta.localDate, "2026-07-03")
    }

    func testStepsRequireExplicitSource() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.today?.steps = CoachContextSourcedInt(value: 8_000, source: "", asOf: referenceDate)

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .stepsSourceExplicit })
        XCTAssertEqual(result.correctedPacket.today?.steps?.source, "healthKit")
    }

    func testWorkoutsRequireExplicitSource() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.training = CoachTrainingContext(
            workoutsToday: 1,
            workouts: [
                CoachContextWorkoutSummary(
                    title: "Run",
                    type: "running",
                    start: referenceDate.addingTimeInterval(-3_600),
                    end: referenceDate,
                    durationMinutes: 35,
                    activeEnergyKcal: 320,
                    source: nil
                )
            ]
        )

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .workoutSourceExplicit })
        XCTAssertEqual(result.correctedPacket.training?.workouts.first?.source, "healthKit")
    }

    func testMissingDataFlagsPopulatedWhenValuesNil() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.today?.steps = nil
        packet.today?.weight = nil
        packet.recentMealsStructured = []
        packet.timeline = CoachContextTimelinePacket(recentEvents: [])
        packet.missingData = CoachMissingDataContext()

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .missingDataPopulated })
        XCTAssertTrue(result.correctedPacket.missingData.stepsMissing)
        XCTAssertTrue(result.correctedPacket.missingData.weightMissing)
        XCTAssertTrue(result.correctedPacket.missingData.noRecentMeals)
        XCTAssertTrue(result.correctedPacket.missingData.noTimelineHistory)
    }

    func testContextSizeMustStayBelowThreshold() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.recentChatMessages = (0..<20).map { index in
            CoachChatMessageContext(
                id: UUID(),
                role: ChatMessageRole.assistant.rawValue,
                text: String(repeating: "Detail \(index). ", count: 40),
                timestamp: referenceDate,
                hasPhotoAttachment: false
            )
        }

        let smallLimit = 512
        let result = CoachContextCorrectnessValidator.validateAndCorrect(
            packet,
            byteLimit: smallLimit,
            calendar: calendar
        )

        XCTAssertTrue(result.issues.contains { $0.rule == .contextSizeBelowThreshold })
        XCTAssertLessThanOrEqual(result.correctedPacket.estimatedEncodedByteCount(), smallLimit)
    }

    func testRedactedSummaryDoesNotLeakMealNames() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.today?.nutrition?.caloriesConsumed = 999

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)
        let summary = CoachContextCorrectnessValidator.redactedSummary(for: result)

        XCTAssertTrue(summary.contains("caloriesMatchConfirmedFood"))
        XCTAssertFalse(summary.contains("Salad"))
    }

    // MARK: Fixtures

    private func timelineFoodEvent(at date: Date, calories: Int) -> CoachTimelineContextEvent {
        CoachTimelineContextEvent(
            id: UUID(),
            timestamp: date,
            type: CoachTimelineEventType.foodLogged.rawValue,
            source: "userConfirmation",
            status: CoachTimelineEventStatus.confirmed.rawValue,
            summary: "Logged food: Meal \(calories)",
            compactPayload: ["name": "Meal \(calories)", "kcal": String(calories)],
            confidence: .high,
            linkedEntryId: UUID(),
            linkedMessageId: nil
        )
    }

    private static func validPacket(
        referenceDate: Date,
        calendar: Calendar
    ) -> CoachContextPacketV2 {
        let meta = CoachContextMeta.make(generatedAt: referenceDate, calendar: calendar)
        let entryId = UUID()

        return CoachContextPacketV2(
            meta: meta,
            today: CoachContextTodayPacket(
                targets: CoachTodayTargetsContext(
                    calorieTarget: 2_000,
                    proteinTarget: 140,
                    carbsTarget: 180,
                    fatTarget: 65,
                    waterTargetMl: 2_500
                ),
                nutrition: CoachTodayNutritionContext(
                    caloriesConsumed: 420,
                    caloriesRemaining: 1_580,
                    proteinConsumed: 48,
                    proteinRemaining: 92,
                    carbsConsumed: 40,
                    carbsRemaining: 140,
                    fatConsumed: 14,
                    fatRemaining: 51
                ),
                hydration: CoachTodayHydrationContext(
                    waterConsumedMl: 1_200,
                    waterRemainingMl: 1_300
                ),
                weight: CoachTodayWeightContext(weightKg: 68.2),
                steps: CoachContextSourcedInt(
                    value: 6_500,
                    source: "healthKit",
                    asOf: referenceDate,
                    confidence: .medium
                )
            ),
            timeline: CoachContextTimelinePacket(
                recentEvents: [
                    CoachTimelineContextEvent(
                        id: UUID(),
                        timestamp: referenceDate,
                        type: CoachTimelineEventType.foodLogged.rawValue,
                        source: "userConfirmation",
                        status: CoachTimelineEventStatus.confirmed.rawValue,
                        summary: "Logged food: Salad",
                        compactPayload: ["name": "Salad", "kcal": "420"],
                        confidence: .high,
                        linkedEntryId: entryId,
                        linkedMessageId: nil
                    )
                ]
            ),
            recentMealsStructured: [
                CoachRecentMealContext(
                    name: "Salad",
                    calories: 420,
                    proteinGrams: 28,
                    loggedAt: referenceDate,
                    localDate: meta.localDate,
                    linkedEntryId: entryId
                )
            ],
            missingData: CoachMissingDataContext(
                weightMissing: false,
                noRecentMeals: false,
                noTimelineHistory: false,
                stepsUnavailable: false
            )
        )
    }
}
