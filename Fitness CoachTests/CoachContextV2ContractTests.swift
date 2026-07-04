//
//  CoachContextV2ContractTests.swift
//  Fitness CoachTests
//
//  iOS ↔ Firebase CoachContextPacketV2 contract coverage for Coach endpoints.
//

import XCTest
@testable import Fitness_Coach

final class CoachContextV2ContractTests: XCTestCase {

    // MARK: Backend fixture decoding

    func testBackendMinimalFixtureDecodesWithSchemaVersion2() throws {
        let packet = try CoachContextV2FixtureLoader.decodeContext(named: "minimal-context")
        XCTAssertEqual(packet.meta.schemaVersion, CoachContextPacketV2.schemaVersion)
        XCTAssertEqual(packet.generationMode, .live)
        XCTAssertTrue(packet.timeline.recentEvents.isEmpty)
    }

    func testBackendRichFixtureDecodesWithLinkedEntryAndTraining() throws {
        let packet = try CoachContextV2FixtureLoader.decodeContext(named: "rich-context")
        XCTAssertEqual(packet.meta.schemaVersion, 2)
        XCTAssertEqual(packet.training?.workoutsToday, 1)
        XCTAssertEqual(packet.recentMealsStructured.first?.linkedEntryId, CoachContextV2ContractFixtures.IDs.linkedEntry)
        XCTAssertEqual(packet.timeline.recentEvents.first?.linkedEntryId, CoachContextV2ContractFixtures.IDs.linkedEntry)
    }

    func testBackendDegradedFixtureDecodesMissingDataFlags() throws {
        let packet = try CoachContextV2FixtureLoader.decodeContext(named: "degraded-context")
        XCTAssertEqual(packet.generationMode, .degraded)
        XCTAssertTrue(packet.missingData.stepsMissing)
        XCTAssertTrue(packet.missingData.noRecentMeals)
        XCTAssertTrue(packet.missingData.healthKitUnavailable)
    }

    func testBackendAnalyzeMealImageFixtureDecodes() throws {
        let root = try CoachContextV2FixtureLoader.decodeJSONObject(named: "analyze-meal-image-request")
        let contextData = try JSONSerialization.data(withJSONObject: root["context"] as Any)
        let context = try CoachContextPacketV2.makeJSONDecoder().decode(
            CoachContextPacketV2.self,
            from: contextData
        )
        let image = root["image"] as? [String: Any]
        let base64 = image?["base64"] as? String ?? ""

        XCTAssertEqual(context.meta.schemaVersion, 2)
        XCTAssertFalse(base64.isEmpty)
        let contextJSON = String(data: contextData, encoding: .utf8) ?? ""
        XCTAssertFalse(contextJSON.contains(String(base64.prefix(16))))
    }

    func testLegacyAIContextShapeDoesNotDecodeAsV2Packet() {
        let legacyJSON = """
        {
          "date": "2026-07-03T12:00:00.000Z",
          "timezoneIdentifier": "UTC",
          "commonFoods": [],
          "recentMessages": [],
          "healthIntelligenceAwarenessAvailable": false
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(
            try CoachContextPacketV2.makeJSONDecoder().decode(CoachContextPacketV2.self, from: legacyJSON)
        )
    }

    // MARK: Swift fixture encoding

    func testSwiftMinimalEncodesSchemaVersion2() throws {
        let data = try CoachContextV2ContractFixtures.minimal.encodedJSONData()
        XCTAssertEqual(try CoachContextV2FixtureLoader.schemaVersion(in: data), 2)
    }

    func testSwiftBuiltMinimalMatchesBackendFixtureSemantics() throws {
        let backend = try CoachContextV2FixtureLoader.decodeContext(named: "minimal-context")
        let swiftBuilt = CoachContextV2ContractFixtures.minimal.clampedForTransport()

        XCTAssertEqual(swiftBuilt.meta.schemaVersion, backend.meta.schemaVersion)
        XCTAssertEqual(swiftBuilt.meta.localDate, backend.meta.localDate)
        XCTAssertEqual(swiftBuilt.generationMode, backend.generationMode)
        XCTAssertEqual(swiftBuilt.timeline.recentEvents.count, backend.timeline.recentEvents.count)
    }

    func testSwiftBuiltRichMatchesBackendFixtureSemantics() throws {
        let backend = try CoachContextV2FixtureLoader.decodeContext(named: "rich-context")
        let swiftBuilt = CoachContextV2ContractFixtures.rich.clampedForTransport()

        XCTAssertEqual(swiftBuilt.meta.schemaVersion, backend.meta.schemaVersion)
        XCTAssertEqual(swiftBuilt.training?.workoutsToday, backend.training?.workoutsToday)
        XCTAssertEqual(swiftBuilt.recentMealsStructured.first?.name, backend.recentMealsStructured.first?.name)
        XCTAssertEqual(
            swiftBuilt.recentMealsStructured.first?.linkedEntryId,
            backend.recentMealsStructured.first?.linkedEntryId
        )
    }

    func testSwiftBuiltDegradedMatchesBackendFixtureSemantics() throws {
        let backend = try CoachContextV2FixtureLoader.decodeContext(named: "degraded-context")
        let swiftBuilt = CoachContextV2ContractFixtures.degraded.clampedForTransport()

        XCTAssertEqual(swiftBuilt.generationMode, backend.generationMode)
        XCTAssertEqual(swiftBuilt.missingData.stepsMissing, backend.missingData.stepsMissing)
        XCTAssertEqual(swiftBuilt.missingData.noRecentMeals, backend.missingData.noRecentMeals)
    }

    // MARK: Endpoint request DTO encoding

    func testClassifyCoachIntentRequestEncodesV2Context() throws {
        let request = AICoachIntentClassificationRequest(
            text: "log 2 eggs",
            context: CoachContextV2ContractFixtures.minimal,
            modelName: "gpt-5-nano",
            modelConfig: .default
        )
        try assertEncodedContextSchemaVersion2(request)
    }

    func testEstimateFoodRequestEncodesV2Context() throws {
        let request = AIFoodEstimateRequest(
            text: "2 eggs",
            context: CoachContextV2ContractFixtures.minimal
        )
        try assertEncodedContextSchemaVersion2(request)
    }

    func testGenerateMealAdviceRequestEncodesV2Context() throws {
        let request = AIMealAdviceRequest(
            question: "Should I eat pasta tonight?",
            context: CoachContextV2ContractFixtures.rich
        )
        try assertEncodedContextSchemaVersion2(request)
    }

    func testGenerateDailyReviewRequestEncodesV2Context() throws {
        let input = DailyReviewAIInput(
            date: CoachContextV2ContractFixtures.Dates.reference,
            calorieTarget: 2_000,
            caloriesConsumed: 1_500,
            caloriesRemaining: 500,
            isOverCalorieTarget: false,
            proteinTarget: 150,
            proteinConsumed: 120,
            proteinRemaining: 30,
            hasMetProteinTarget: false,
            carbsTarget: 200,
            carbsConsumed: 180,
            carbsRemaining: 20,
            fatTarget: 65,
            fatConsumed: 50,
            fatRemaining: 15,
            waterTargetMl: 2_500,
            waterConsumedMl: 1_800,
            waterRemainingMl: 700,
            hasMetWaterTarget: false,
            weightKg: nil,
            latestWeightKg: nil,
            steps: nil,
            workoutCount: 0,
            workoutCaloriesBurned: 0,
            foodEntryCount: 2,
            lowConfidenceFoodCount: 0,
            topProteinFoodNames: [],
            deterministicNotes: []
        )
        let request = AIDailyReviewRequest(
            input: input,
            context: CoachContextV2ContractFixtures.minimal
        )
        try assertEncodedContextSchemaVersion2(request)
    }

    func testParseEditDeleteRequestEncodesV2Context() throws {
        let request = AIEditDeleteParseRequest(
            text: "delete my last meal",
            context: CoachContextV2ContractFixtures.rich
        )
        try assertEncodedContextSchemaVersion2(request)
    }

    func testParseMultiActionRequestEncodesV2Context() throws {
        let request = AIMultiActionParseRequest(
            text: "log water and log weight",
            context: CoachContextV2ContractFixtures.minimal
        )
        try assertEncodedContextSchemaVersion2(request)
    }

    func testAnalyzeMealImageRequestKeepsImageOutsideContext() throws {
        let request = CoachContextV2ContractFixtures.analyzeMealImageRequest
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertEqual(request.context.meta.schemaVersion, 2)
        XCTAssertTrue(json.contains("\"image\""))
        XCTAssertFalse(json.contains(request.image.base64))
    }

    // MARK: Helpers

    private func assertEncodedContextSchemaVersion2<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let context = root?["context"] as? [String: Any]
        let meta = context?["meta"] as? [String: Any]
        XCTAssertEqual(meta?["schemaVersion"] as? Int, CoachContextPacketV2.schemaVersion)
    }
}
