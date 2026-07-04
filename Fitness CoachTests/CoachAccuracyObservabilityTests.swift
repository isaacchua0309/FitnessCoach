//
//  CoachAccuracyObservabilityTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachAccuracyObservabilityTests: XCTestCase {

    func testProductionLogLineUsesRedactedFieldsOnly() {
        let fields = CoachAccuracyObservabilityLogFormatter.fields(
            from: CoachRouteObservabilitySnapshot(
                routeSelected: "mealAdvice",
                routeSource: "classifier",
                classifierIntent: "nutritionAdvice",
                classifierConfidence: "0.82",
                modelTier: "strong",
                requiresAPI: true,
                messageLength: 42
            )
        )

        let line = CoachAccuracyObservabilityLogFormatter.productionLogLine(
            event: "route_selected",
            fields: fields
        )

        XCTAssertTrue(line.contains("event=route_selected"))
        XCTAssertTrue(line.contains("messageLength=42"))
        XCTAssertTrue(line.contains("classifierIntent=nutritionAdvice"))
        XCTAssertFalse(line.contains("secret lunch message"))
        XCTAssertFalse(line.contains("Bearer"))
    }

    func testContextSnapshotFieldsIncludeRequiredMetrics() {
        let packet = CoachContextPacketV2(
            meta: CoachContextMeta.make(generatedAt: Date()),
            timeline: CoachContextTimelinePacket(recentEvents: []),
            recentMealsStructured: [],
            commonFoods: [],
            missingData: CoachMissingDataContext(),
            assumptions: [],
            generationMode: .live
        )

        let snapshot = CoachContextObservabilitySnapshot.from(
            packet,
            compactionOccurred: true,
            fallbackPacketUsed: false
        )

        let fields = CoachAccuracyObservabilityLogFormatter.fields(from: snapshot)

        XCTAssertEqual(fields["contextSchemaVersion"], "2")
        XCTAssertEqual(fields["contextGenerationMode"], "live")
        XCTAssertNotNil(fields["contextSizeBucket"])
        XCTAssertEqual(fields["compactionOccurred"], "true")
        XCTAssertEqual(fields["fallbackPacketUsed"], "false")
        XCTAssertEqual(fields["healthIntelligencePresent"], "false")
    }

    func testRedactSensitiveJSONFieldsStripsContextTokensAndImages() {
        let raw = """
        {"text":"log my chicken salad","context":{"recentMealsStructured":[{"name":"Salad"}]},"imageJPEGBase64":"abc123","name":"private meal","summary":"800 kcal lunch","token":"Bearer secret"}
        """
        let sanitized = CoachAccuracyObservabilityLogFormatter.redactSensitiveJSONFields(raw)

        XCTAssertTrue(sanitized.contains("\"text\":\"<redacted>\""))
        XCTAssertTrue(sanitized.contains("\"context\":\"<redacted>\""))
        XCTAssertTrue(sanitized.contains("\"imageJPEGBase64\":\"<redacted>\""))
        XCTAssertTrue(sanitized.contains("\"name\":\"<redacted>\""))
        XCTAssertTrue(sanitized.contains("\"summary\":\"<redacted>\""))
        XCTAssertFalse(sanitized.contains("log my chicken salad"))
        XCTAssertFalse(sanitized.contains("abc123"))
        XCTAssertFalse(sanitized.contains("Bearer secret"))
    }

    func testFoodEstimateTrustObservabilityFields() {
        let draft = AIFoodConfirmationDraft(
            originalText: "log chicken rice",
            assistantMessage: nil,
            mealDraft: FoodLogDraft(
                displayName: "Chicken rice",
                components: [
                    FoodComponent(name: "Chicken rice", calories: 520, protein: 30, carbs: 60, fat: 15)
                ],
                confidence: .medium,
                assumptions: ["Medium plate"],
                caloriesRangeLower: 450,
                caloriesRangeUpper: 750
            ),
            confidence: .medium,
            requiresConfirmation: true,
            sanityFailed: true,
            requiresEditBeforeConfirm: true
        )

        let snapshot = CoachFoodEstimateTrustObservabilitySnapshot.from(draft)
        let fields = CoachAccuracyObservabilityLogFormatter.fields(from: snapshot)

        XCTAssertEqual(fields["confidenceBucket"], "medium")
        XCTAssertEqual(fields["sanityFailed"], "true")
        XCTAssertEqual(fields["hasCalorieRange"], "true")
        XCTAssertEqual(fields["requiresEditBeforeConfirm"], "true")
        XCTAssertEqual(fields["assumptionCount"], "1")
    }

    func testRedactedDebugDescriptionExcludesFoodNamesAndTokens() {
        let packet = CoachContextPacketV2(
            meta: CoachContextMeta.make(generatedAt: Date()),
            timeline: CoachContextTimelinePacket(recentEvents: []),
            recentMealsStructured: [
                CoachRecentMealContext(
                    name: "Secret Salmon Bowl",
                    calories: 620,
                    proteinGrams: 42,
                    carbsGrams: 48,
                    fatGrams: 22,
                    localDate: "2026-07-03",
                    source: FoodEntrySource.manual.rawValue,
                    confidence: .high
                )
            ],
            commonFoods: [],
            missingData: CoachMissingDataContext(stepsUnavailable: true),
            assumptions: [],
            generationMode: .live
        )

        let summary = packet.redactedDebugDescription()

        XCTAssertTrue(summary.contains("meals=1"))
        XCTAssertTrue(summary.contains("mode=live"))
        XCTAssertFalse(summary.contains("Secret Salmon Bowl"))
        XCTAssertFalse(summary.contains("Bearer"))
    }

    func testEndpointSnapshotIncludesValidationAndErrorCategory() {
        let fields = CoachAccuracyObservabilityLogFormatter.fields(
            from: CoachEndpointObservabilitySnapshot(
                endpoint: "analyzeMealImage",
                validationSuccess: false,
                backendErrorCategory: "invalid_nutrition_json",
                durationMs: 1200
            )
        )

        XCTAssertEqual(fields["endpoint"], "analyzeMealImage")
        XCTAssertEqual(fields["responseValidationSuccess"], "false")
        XCTAssertEqual(fields["backendErrorCategory"], "invalid_nutrition_json")
        XCTAssertEqual(fields["durationMs"], "1200")
    }

    func testSizeBucketBoundaries() {
        XCTAssertEqual(CoachAccuracyObservabilityLogFormatter.sizeBucket(byteCount: 100), "<4k")
        XCTAssertEqual(CoachAccuracyObservabilityLogFormatter.sizeBucket(byteCount: 4_096), "4k-8k")
        XCTAssertEqual(CoachAccuracyObservabilityLogFormatter.sizeBucket(byteCount: 30_000), ">24k")
    }
}
