//
//  CoachContextPacketV2Tests.swift
//  Fitness CoachTests
//
//  Forma — CoachContextPacketV2 encoding, omission, and size guard tests.
//

import XCTest
@testable import Fitness_Coach

final class CoachContextPacketV2Tests: XCTestCase {

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

    // MARK: Encoding

    func testEncodesFullPacketRoundTrip() throws {
        let packet = Self.samplePacket(referenceDate: referenceDate, calendar: calendar)
        let data = try packet.encodedJSONData()
        let decoded = try CoachContextPacketV2.makeJSONDecoder().decode(CoachContextPacketV2.self, from: data)

        XCTAssertEqual(decoded, packet)
        XCTAssertEqual(decoded.meta.schemaVersion, CoachContextPacketV2.schemaVersion)
        XCTAssertEqual(decoded.meta.localDate, "2026-07-03")
        XCTAssertEqual(decoded.timeline.recentEvents.count, 1)
        XCTAssertEqual(decoded.recentMealsStructured.first?.name, "Salad")
        XCTAssertEqual(decoded.commonFoods.first?.name, "Oatmeal")
    }

    func testEncodesWithMissingOptionalFields() throws {
        let packet = CoachContextPacketV2(
            meta: CoachContextMeta.make(generatedAt: referenceDate, calendar: calendar),
            missingData: CoachMissingDataContext(
                stepsMissing: true,
                noRecentMeals: true,
                noTimelineHistory: true
            ),
            generationMode: .degraded
        )

        let data = try packet.encodedJSONData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json?["meta"])
        XCTAssertNil(json?["profile"])
        XCTAssertNil(json?["today"])
        XCTAssertNil(json?["training"])
        XCTAssertNil(json?["healthIntelligence"])
        XCTAssertNil(json?["sourceAttribution"])

        let missing = json?["missingData"] as? [String: Any]
        XCTAssertEqual(missing?["stepsMissing"] as? Bool, true)
        XCTAssertEqual(missing?["noRecentMeals"] as? Bool, true)
    }

    // MARK: Payload size

    func testFitsWithinDefaultByteLimitForTypicalPacket() {
        let packet = Self.samplePacket(referenceDate: referenceDate, calendar: calendar)
        XCTAssertTrue(packet.fitsWithinByteLimit())
        XCTAssertLessThanOrEqual(
            packet.estimatedEncodedByteCount(),
            CoachContextPacketV2Limits.defaultMaxEncodedBytes
        )
    }

    func testClampedPacketReducesOversizedTimeline() throws {
        var events: [CoachTimelineContextEvent] = []
        for index in 0..<60 {
            events.append(
                CoachTimelineContextEvent(
                    id: UUID(),
                    timestamp: referenceDate.addingTimeInterval(TimeInterval(index)),
                    type: CoachTimelineEventType.foodLogged.rawValue,
                    source: CoachTimelineEventSourceAttribution.system.rawValue,
                    status: CoachTimelineEventStatus.confirmed.rawValue,
                    summary: "Logged food item number \(index) with extra detail",
                    compactPayload: [
                        "name": "Item \(index)",
                        "kcal": "\(400 + index)"
                    ],
                    confidence: .medium,
                    linkedEntryId: UUID()
                )
            )
        }

        let packet = CoachContextPacketV2(
            meta: CoachContextMeta.make(generatedAt: referenceDate, calendar: calendar),
            timeline: CoachContextTimelinePacket(recentEvents: events)
        )

        XCTAssertFalse(packet.fitsWithinByteLimit(4_096))

        let clamped = packet.clampedForTransport()
        XCTAssertEqual(clamped.timeline.recentEvents.count, CoachContextPacketV2Limits.maxTimelineEvents)
        XCTAssertTrue(clamped.fitsWithinByteLimit())
    }

    func testTimelineEventSummaryIsClampedForTransport() {
        let longSummary = String(repeating: "x", count: 300)
        let event = CoachTimelineContextEvent(
            id: UUID(),
            timestamp: referenceDate,
            type: CoachTimelineEventType.userMessage.rawValue,
            source: CoachTimelineEventSourceAttribution.localParser.rawValue,
            status: CoachTimelineEventStatus.confirmed.rawValue,
            summary: longSummary
        )

        let clamped = event.clampedForTransport()
        XCTAssertLessThanOrEqual(clamped.summary.count, CoachContextPacketV2Limits.maxSummaryLength + 1)
    }

    // MARK: Debug description

    func testRedactedDebugDescriptionOmitsSensitivePayload() {
        let packet = Self.samplePacket(referenceDate: referenceDate, calendar: calendar)
        let description = packet.redactedDebugDescription()

        XCTAssertTrue(description.contains("CoachContextPacketV2"))
        XCTAssertTrue(description.contains("timelineEvents=1"))
        XCTAssertFalse(description.contains("Salad"))
        XCTAssertFalse(description.contains("Oatmeal"))
    }

    // MARK: Bridges

    func testTimelineEventBridgeFromDomainEvent() {
        let domainEvent = CoachTimelineEvent.make(
            type: .waterLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .waterLogged(WaterLoggedPayload(entryId: UUID(), amountMl: 500)),
            occurredAt: referenceDate,
            calendar: calendar,
            link: CoachTimelineEventLink(linkedEntryId: UUID())
        )

        let bridged = CoachTimelineContextEvent.from(
            event: domainEvent,
            summary: CoachTimelineEventSummaryBuilder.summary(for: domainEvent)
        )

        XCTAssertEqual(bridged.type, CoachTimelineEventType.waterLogged.rawValue)
        XCTAssertEqual(bridged.compactPayload?["ml"], "500")
        XCTAssertEqual(bridged.confidence, nil)
    }

    func testMissingDataLabels() {
        let missing = CoachMissingDataContext(
            stepsMissing: true,
            workoutPermissionDeniedOrUnavailable: true,
            hrvMissing: true
        )
        XCTAssertEqual(missing.missingSignalLabels, ["steps", "workouts", "hrv"])
        XCTAssertTrue(missing.hasAnyMissingSignals)
    }

    // MARK: Fixtures

    private static func samplePacket(referenceDate: Date, calendar: Calendar) -> CoachContextPacketV2 {
        let entryId = UUID()
        let timelineEvent = CoachTimelineContextEvent(
            id: UUID(),
            timestamp: referenceDate,
            type: CoachTimelineEventType.foodLogged.rawValue,
            source: CoachTimelineEventSourceAttribution.userConfirmation.rawValue,
            status: CoachTimelineEventStatus.confirmed.rawValue,
            summary: "Logged food: Salad",
            compactPayload: ["name": "Salad", "kcal": "420"],
            confidence: .medium,
            linkedEntryId: entryId
        )

        return CoachContextPacketV2(
            meta: CoachContextMeta.make(generatedAt: referenceDate, calendar: calendar),
            profile: CoachUserProfileContext(
                age: 32,
                sex: .female,
                heightCm: 168,
                currentWeightKg: 68,
                goalWeightKg: 64,
                activityLevel: .moderatelyActive,
                trainingFrequencyPerWeek: 4,
                goalType: "Lose Fat"
            ),
            today: CoachContextTodayPacket(
                targets: CoachTodayTargetsContext(
                    calorieTarget: 2_000,
                    proteinTarget: 140,
                    carbsTarget: 180,
                    fatTarget: 65,
                    waterTargetMl: 2_500
                ),
                nutrition: CoachTodayNutritionContext(
                    caloriesConsumed: 1_250,
                    caloriesRemaining: 750,
                    proteinConsumed: 85,
                    proteinRemaining: 55,
                    carbsConsumed: 120,
                    carbsRemaining: 60,
                    fatConsumed: 40,
                    fatRemaining: 25
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
                ),
                workoutCaloriesBurned: CoachContextSourcedInt(
                    value: 320,
                    source: "healthKit",
                    asOf: referenceDate,
                    confidence: .high
                )
            ),
            training: CoachTrainingContext(
                workoutsToday: 1,
                workouts: [
                    CoachContextWorkoutSummary(
                        title: "Run",
                        type: "running",
                        start: referenceDate.addingTimeInterval(-3_600),
                        end: referenceDate,
                        durationMinutes: 35,
                        activeEnergyKcal: 320
                    )
                ],
                trainingLoad: "moderate",
                recoveryStatus: "fair",
                readiness: "moderate"
            ),
            timeline: CoachContextTimelinePacket(recentEvents: [timelineEvent]),
            recentMealsStructured: [
                CoachRecentMealContext(
                    name: "Salad",
                    quantity: 1,
                    unit: "bowl",
                    calories: 420,
                    proteinGrams: 28,
                    carbsGrams: 30,
                    fatGrams: 14,
                    loggedAt: referenceDate,
                    source: FoodEntrySource.manual.rawValue,
                    confidence: .high,
                    linkedEntryId: entryId
                )
            ],
            commonFoods: [
                CoachCommonFoodContext(
                    name: "Oatmeal",
                    logCount: 12,
                    lastLoggedAt: referenceDate,
                    typicalCalories: 300
                )
            ],
            missingData: CoachMissingDataContext(sleepMissing: true),
            assumptions: [
                CoachAssumptionContext(
                    key: "steps_source",
                    detail: "Steps sourced from Apple Health when authorized.",
                    confidence: .medium
                )
            ],
            generationMode: .live,
            sourceAttribution: CoachContextSourceAttribution(
                generationMode: .live,
                timelineEventCount: 1,
                recentMealCount: 1,
                commonFoodCount: 1,
                healthIntelligenceIncluded: false,
                sources: ["swiftData", "healthKit"]
            )
        )
    }
}
