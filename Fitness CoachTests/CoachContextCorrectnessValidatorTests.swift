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

    func testMacrosConsumedMustMatchConfirmedFoodEntries() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.today?.nutrition?.proteinConsumed = 99
        packet.today?.nutrition?.carbsConsumed = 99
        packet.today?.nutrition?.fatConsumed = 99

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .macrosMatchConfirmedFood })
        XCTAssertEqual(result.correctedPacket.today?.nutrition?.proteinConsumed ?? 0, 28, accuracy: 0.01)
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
        XCTAssertEqual(result.correctedPacket.today?.nutrition?.proteinRemaining ?? 0, 112, accuracy: 0.01)
        XCTAssertEqual(result.correctedPacket.today?.hydration?.waterRemainingMl, 1_300)
    }

    func testOverTargetAllowsNegativeRemainingAndSetsFlag() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.today?.targets?.calorieTarget = 2_000
        packet.today?.nutrition?.caloriesConsumed = 2_300
        packet.today?.nutrition?.caloriesRemaining = -300
        packet.today?.nutrition?.caloriesOverTarget = nil
        packet.recentMealsStructured[0].calories = 2_300
        packet.timeline.recentEvents[0].compactPayload = ["name": "Salad", "kcal": "2300"]

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .overTargetFlagsConsistent })
        XCTAssertEqual(result.correctedPacket.today?.nutrition?.caloriesRemaining, -300)
        XCTAssertEqual(result.correctedPacket.today?.nutrition?.caloriesOverTarget, true)
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
                    compactPayload: ["kcal": "800"],
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

    func testAssistantTextDoesNotPromoteStructuredFacts() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.recentMealsStructured = []
        packet.today?.nutrition?.caloriesConsumed = 900
        packet.recentChatMessages = [
            CoachChatMessageContext(
                id: UUID(),
                role: ChatMessageRole.assistant.rawValue,
                text: "I logged your chicken rice at 900 kcal.",
                timestamp: referenceDate,
                hasPhotoAttachment: false
            )
        ]
        packet.recentMealsStructured = [
            CoachRecentMealContext(
                name: "Chicken rice",
                calories: 900,
                proteinGrams: 40,
                localDate: packet.meta.localDate,
                source: CoachTimelineEventSourceAttribution.estimateFood.rawValue
            )
        ]

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .assistantTextNotInStructuredFacts })
        XCTAssertTrue(result.correctedPacket.recentMealsStructured.isEmpty)
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

    func testMealLoggedAtMustMatchLocalDateInTimezone() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.recentMealsStructured[0].loggedAt = referenceDate.addingTimeInterval(-86_400)

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .timelineEventLocalDateConsistent })
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

    func testRecentMealsRequireSourceOrLinkedEntryId() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.recentMealsStructured = [
            CoachRecentMealContext(
                name: "Mystery meal",
                calories: 500,
                proteinGrams: 30,
                localDate: packet.meta.localDate
            )
        ]

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .recentMealsSourceAttribution })
        XCTAssertEqual(result.correctedPacket.recentMealsStructured.first?.source, "unknown")
    }

    func testMissingStepsSourceFlagsMissingData() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.today?.steps = nil
        packet.missingData = CoachMissingDataContext()

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .missingDataPopulated })
        XCTAssertTrue(result.correctedPacket.missingData.stepsMissing)
    }

    func testHealthKitDeniedMustNotSilentlyReportZeroSteps() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.today?.steps = CoachContextSourcedInt(value: 0, source: "healthKit", asOf: referenceDate)
        packet.missingData.healthKitDenied = true
        packet.missingData.stepsUnavailable = true

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .healthStepsNotSilentlyZero })
        XCTAssertNil(result.correctedPacket.today?.steps)
        XCTAssertTrue(result.correctedPacket.missingData.stepsMissing)
    }

    func testHealthKitDeniedMustNotSilentlyReportZeroWorkouts() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.training = CoachTrainingContext(workoutsToday: 0)
        packet.missingData.healthKitDenied = true
        packet.missingData.workoutsUnavailable = true

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .healthWorkoutsNotSilentlyZero })
        XCTAssertNil(result.correctedPacket.training?.workoutsToday)
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

    func testRejectedFoodEventsRemovedFromTimelineExport() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.timeline.recentEvents.append(
            CoachTimelineContextEvent(
                id: UUID(),
                timestamp: referenceDate.addingTimeInterval(60),
                type: CoachTimelineEventType.foodRejected.rawValue,
                source: "estimateFood",
                status: CoachTimelineEventStatus.rejected.rawValue,
                summary: "Rejected burger",
                compactPayload: ["kcal": "600"],
                confidence: .medium,
                linkedEntryId: nil,
                linkedMessageId: nil
            )
        )

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .rejectedEventsExcludedFromTimeline })
        XCTAssertFalse(
            result.correctedPacket.timeline.recentEvents.contains {
                $0.type == CoachTimelineEventType.foodRejected.rawValue
            }
        )
    }

    func testEditDeleteConsistencyRemovesDeletedMealsFromStructuredFacts() {
        let deletedEntryID = UUID()
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.recentMealsStructured.append(
            CoachRecentMealContext(
                name: "Snack",
                calories: 180,
                proteinGrams: 8,
                localDate: packet.meta.localDate,
                linkedEntryId: deletedEntryID
            )
        )
        packet.timeline.recentEvents.append(
            CoachTimelineContextEvent(
                id: UUID(),
                timestamp: referenceDate.addingTimeInterval(120),
                type: CoachTimelineEventType.foodDeleted.rawValue,
                source: "userConfirmation",
                status: CoachTimelineEventStatus.confirmed.rawValue,
                summary: "Deleted snack",
                compactPayload: ["kcal": "180"],
                confidence: .high,
                linkedEntryId: deletedEntryID,
                linkedMessageId: nil
            )
        )

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .editDeleteTimelineConsistency })
        XCTAssertFalse(
            result.correctedPacket.recentMealsStructured.contains { $0.linkedEntryId == deletedEntryID }
        )
    }

    func testCorruptedTimelinePayloadIsSanitized() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.recentMealsStructured = []
        packet.today?.nutrition?.caloriesConsumed = 0
        packet.timeline.recentEvents = [
            CoachTimelineContextEvent(
                id: UUID(),
                timestamp: referenceDate,
                type: CoachTimelineEventType.foodLogged.rawValue,
                source: "userConfirmation",
                status: CoachTimelineEventStatus.confirmed.rawValue,
                summary: "Logged food",
                compactPayload: ["kcal": "-50"],
                confidence: .high,
                linkedEntryId: UUID(),
                linkedMessageId: nil
            )
        ]

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .corruptedTimelinePayload })
        XCTAssertEqual(result.correctedPacket.timeline.recentEvents.first?.compactPayload?["kcal"], "0")
    }

    func testPrivacySensitiveContentIsRedacted() {
        var packet = Self.validPacket(referenceDate: referenceDate, calendar: calendar)
        packet.currentUserMessage = "Bearer sk-live-secret-token"
        packet.timeline.recentEvents.append(
            CoachTimelineContextEvent(
                id: UUID(),
                timestamp: referenceDate.addingTimeInterval(30),
                type: CoachTimelineEventType.authError.rawValue,
                source: "system",
                status: CoachTimelineEventStatus.failed.rawValue,
                summary: "401 unauthorized token=abc123",
                compactPayload: nil,
                confidence: nil,
                linkedEntryId: nil,
                linkedMessageId: nil
            )
        )

        let result = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)

        XCTAssertTrue(result.issues.contains { $0.rule == .privacySensitiveContent })
        XCTAssertEqual(result.correctedPacket.currentUserMessage, "<redacted>")
        XCTAssertFalse(
            result.correctedPacket.timeline.recentEvents.contains {
                $0.type == CoachTimelineEventType.authError.rawValue
            }
        )
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
        XCTAssertEqual(result.correctedPacket.generationMode, .degraded)
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
                    proteinConsumed: 28,
                    proteinRemaining: 112,
                    carbsConsumed: nil,
                    carbsRemaining: nil,
                    fatConsumed: nil,
                    fatRemaining: nil,
                    caloriesOverTarget: false,
                    proteinOverTarget: false,
                    carbsOverTarget: false,
                    fatOverTarget: false
                ),
                hydration: CoachTodayHydrationContext(
                    waterConsumedMl: 1_200,
                    waterRemainingMl: 1_300,
                    waterOverTarget: false
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
                    source: "userConfirmation",
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
