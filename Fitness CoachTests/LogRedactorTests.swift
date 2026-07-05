//
//  LogRedactorTests.swift
//  Fitness CoachTests
//
//  Forma — Verifies shared logging redaction helpers.
//

import XCTest
@testable import Fitness_Coach

final class LogRedactorTests: XCTestCase {

    private let sampleUID = "firebase-user-uid-abcdefghijklmnop"

    // MARK: - Identifiers

    func testHashedUIDIsShortAndStable() {
        let hash = LogRedactor.hashedUID(sampleUID)
        XCTAssertEqual(hash.count, 8)
        XCTAssertEqual(hash, LogRedactor.hashedUID(sampleUID))
        XCTAssertFalse(hash.contains(sampleUID))
    }

    func testRedactUIDShowsSuffixOnly() {
        let redacted = LogRedactor.redactUID(sampleUID)
        XCTAssertTrue(redacted.hasPrefix("***"))
        XCTAssertFalse(redacted.contains(sampleUID.prefix(10)))
    }

    func testPrivacySafeUIDPrefixUsesHash() {
        XCTAssertEqual(
            AccountDeletionPolicy.privacySafeUIDField(sampleUID),
            LogRedactor.hashedUID(sampleUID)
        )
    }

    // MARK: - Secrets

    func testRedactSecretsStripsBearerJWTAndEmail() {
        let raw = "user@test.com Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig api_key=secret123"
        let redacted = LogRedactor.redactSecrets(in: raw)

        XCTAssertFalse(redacted.contains("user@test.com"))
        XCTAssertFalse(redacted.contains("Bearer eyJ"))
        XCTAssertFalse(redacted.contains("secret123"))
        XCTAssertTrue(redacted.contains(LogRedactor.secretRedactedPlaceholder))
    }

    // MARK: - JSON

    func testRedactSensitiveJSONFieldsStripsFoodTextAndImages() {
        let raw = """
        {"text":"log chicken salad","message":"private lunch","name":"Salad","summary":"800 kcal","base64":"abc123","imageJPEGBase64":"raw","context":{"meals":1},"token":"Bearer secret"}
        """
        let sanitized = LogRedactor.redactSensitiveJSONFields(raw)

        XCTAssertTrue(sanitized.contains("\"text\":\"\(LogRedactor.jsonRedactedPlaceholder)\""))
        XCTAssertTrue(sanitized.contains("\"message\":\"\(LogRedactor.jsonRedactedPlaceholder)\""))
        XCTAssertTrue(sanitized.contains("\"name\":\"\(LogRedactor.jsonRedactedPlaceholder)\""))
        XCTAssertTrue(sanitized.contains("\"summary\":\"\(LogRedactor.jsonRedactedPlaceholder)\""))
        XCTAssertTrue(sanitized.contains("\"base64\":\"\(LogRedactor.jsonRedactedPlaceholder)\""))
        XCTAssertFalse(sanitized.contains("chicken salad"))
        XCTAssertFalse(sanitized.contains("abc123"))
        XCTAssertFalse(sanitized.contains("Bearer secret"))
    }

    func testCoachFormattersDelegateToLogRedactor() {
        let raw = "{\"message\":\"private\",\"text\":\"secret\",\"name\":\"meal\"}"
        let image = CoachImageAnalysisDebugLogFormatter.redactSensitiveJSONFields(raw)
        let accuracy = CoachAccuracyObservabilityLogFormatter.redactSensitiveJSONFields(raw)

        XCTAssertEqual(image, accuracy)
        XCTAssertFalse(image.contains("private"))
        XCTAssertFalse(image.contains("secret"))
    }

    // MARK: - Field sanitization

    func testSanitizeLogFieldsAllowsAggregateSyncMetrics() {
        let fields = LogRedactor.sanitizeLogFields([
            "pulledFoodEntries": "12",
            "foodEntriesRestored": "8",
            "uid": sampleUID,
            "mealName": "Secret Bowl",
            "userMessage": "log my lunch"
        ])

        XCTAssertEqual(fields["pulledFoodEntries"], "12")
        XCTAssertEqual(fields["foodEntriesRestored"], "8")
        XCTAssertEqual(fields["uidHash"], LogRedactor.hashedUID(sampleUID))
        XCTAssertNil(fields["mealName"])
        XCTAssertNil(fields["userMessage"])
        XCTAssertNil(fields["uid"])
    }

    func testSanitizeLogFieldsStripsSensitiveValues() {
        let fields = LogRedactor.sanitizeLogFields([
            "errorCategory": "network",
            "note": "Bearer eyJhbGciOiJIUzI1NiJ9.test.sig"
        ])

        XCTAssertEqual(fields["errorCategory"], "network")
        XCTAssertNil(fields["note"])
    }

    // MARK: - Buckets

    func testCalorieAndWeightBucketsDoNotExposeRawValues() {
        XCTAssertEqual(LogRedactor.calorieBucket(650), "500-799")
        XCTAssertEqual(LogRedactor.weightBucketKg(72.4), "60-79kg")
        XCTAssertFalse(LogRedactor.calorieBucket(650).contains("650"))
        XCTAssertFalse(LogRedactor.weightBucketKg(72.4).contains("72"))
    }

    // MARK: - Privacy-safe typed fields

    func testPrivacySafeLogFieldsSanitizesOutput() {
        let fields = PrivacySafeLogFields.sanitized([
            "event": .eventName("sync_completed"),
            "uid": .uidHash(LogRedactor.hashedUID(sampleUID)),
            "count": .count(3),
            "foodName": .category("should_be_stripped_if_key_sensitive")
        ])

        XCTAssertEqual(fields["event"], "sync_completed")
        XCTAssertEqual(fields["count"], "3")
        XCTAssertNil(fields["foodName"])
    }

    // MARK: - Health formatting

    func testHealthOSLogFormattingSanitizesFields() {
        let line = HealthOSLogFormatting.message(
            "sync completed",
            fields: [
                "trigger": "foreground",
                "reviewText": "Great day of eating",
                "uid": sampleUID
            ]
        )

        XCTAssertTrue(line.contains("trigger=foreground"))
        XCTAssertFalse(line.contains("Great day"))
        XCTAssertFalse(line.contains(sampleUID))
        XCTAssertTrue(line.contains("uidHash="))
    }

    // MARK: - Production observability line

    func testProductionObservabilityLineHasNoRawUserContent() {
        let line = CoachAccuracyObservabilityLogFormatter.productionLogLine(
            event: "route_selected",
            fields: LogRedactor.sanitizeLogFields([
                "routeSelected": "mealAdvice",
                "messageLength": "18",
                "userMessage": "log my private lunch"
            ])
        )

        XCTAssertTrue(line.contains("event=route_selected"))
        XCTAssertTrue(line.contains("messageLength=18"))
        XCTAssertFalse(line.contains("private lunch"))
    }
}
