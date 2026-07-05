//
//  FormaLogRedactorTests.swift
//  Fitness CoachTests
//
//  Forma — Verifies centralized log redaction primitives.
//

import XCTest
@testable import Fitness_Coach

final class FormaLogRedactorTests: XCTestCase {

    private let sampleUID = "firebase-user-uid-abcdefghijklmnop"
    private let firebaseUID = "xK3mN9pQrS2tUvWxYzAbCdEfGh"

    // MARK: - Required coverage

    func testRedactsEmail() {
        let raw = "contact user@example.com for help"
        let redacted = FormaLogRedactor.redactSecrets(in: raw)

        XCTAssertFalse(redacted.contains("user@example.com"))
        XCTAssertTrue(redacted.contains(FormaLogRedactor.secretPlaceholder))
        XCTAssertTrue(redacted.hasPrefix("contact "))
    }

    func testRedactsBearerToken() {
        let raw = "Authorization failed Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig"
        let redacted = FormaLogRedactor.redactSecrets(in: raw)

        XCTAssertFalse(redacted.contains("Bearer eyJ"))
        XCTAssertTrue(redacted.contains(FormaLogRedactor.secretPlaceholder))
        XCTAssertTrue(redacted.contains("Authorization failed"))
    }

    func testRedactsAPIKeyStyleText() {
        let raw = "config api_key=sk-live-secret-12345 loaded"
        let redacted = FormaLogRedactor.redactSecrets(in: raw)

        XCTAssertFalse(redacted.contains("sk-live-secret-12345"))
        XCTAssertTrue(redacted.contains(FormaLogRedactor.secretPlaceholder))
        XCTAssertTrue(redacted.contains("config"))
        XCTAssertTrue(redacted.contains("loaded"))
    }

    func testRedactsURLQueryValues() {
        let raw = "GET https://api.example.com/v1/sync?token=abc123&userId=firebase-user-uid-abcdefghijklmnop"
        let redacted = FormaLogRedactor.redactURLQueryValues(in: raw)

        XCTAssertTrue(redacted.contains("token=\(FormaLogRedactor.secretPlaceholder)"))
        XCTAssertTrue(redacted.contains("userId=\(FormaLogRedactor.secretPlaceholder)"))
        XCTAssertFalse(redacted.contains("abc123"))
        XCTAssertTrue(redacted.contains("https://api.example.com/v1/sync"))
    }

    func testPreservesNonSensitiveContext() {
        let raw = "sync_run_completed status=success durationMs=42 reason=foreground"
        let redacted = FormaLogRedactor.redactSecrets(in: raw)

        XCTAssertEqual(redacted, raw)
    }

    func testHandlesNilAndEmptyStrings() {
        XCTAssertNil(FormaLogRedactor.redact(nil))
        XCTAssertEqual(FormaLogRedactor.redactSecrets(in: ""), "")
        XCTAssertEqual(FormaLogRedactor.redact(""), "")
    }

    func testIdempotentRedaction() {
        let raw = "user@test.com Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig api_key=secret"
        let once = FormaLogRedactor.redactSecrets(in: raw)
        let twice = FormaLogRedactor.redactSecrets(in: once)

        XCTAssertEqual(once, twice)
    }

    // MARK: - Identifiers

    func testHashedUIDIsShortAndStable() {
        let hash = FormaLogRedactor.hashedUID(sampleUID)
        XCTAssertEqual(hash.count, 8)
        XCTAssertEqual(hash, FormaLogRedactor.hashedUID(sampleUID))
        XCTAssertFalse(hash.contains(sampleUID))
    }

    func testRedactUIDShowsSuffixOnly() {
        let redacted = FormaLogRedactor.redactUID(sampleUID)
        XCTAssertTrue(redacted.hasPrefix("***"))
        XCTAssertFalse(redacted.contains(sampleUID.prefix(10)))
    }

    func testRedactsFirebaseUIDLikeIdentifiersInFreeText() {
        let raw = "restore owner=\(firebaseUID) complete"
        let redacted = FormaLogRedactor.redactSecrets(in: raw)

        XCTAssertFalse(redacted.contains(firebaseUID))
        XCTAssertTrue(redacted.contains("restore owner="))
        XCTAssertTrue(redacted.contains("complete"))
    }

    func testRedactsUsersPathSegments() {
        let raw = "permission denied for users/xK3mN9pQrS2tUvWxYzAbCdEfGh/documents"
        let redacted = FormaLogRedactor.redactSecrets(in: raw)

        XCTAssertFalse(redacted.contains("xK3mN9pQrS2tUvWxYzAbCdEfGh"))
        XCTAssertTrue(redacted.contains("permission denied for \(FormaLogRedactor.secretPlaceholder)/documents"))
    }

    // MARK: - LogRedactor delegation

    func testLogRedactorDelegatesCoreRedactionToFormaLogRedactor() {
        let raw = "user@test.com token=abc"
        XCTAssertEqual(LogRedactor.redactSecrets(in: raw), FormaLogRedactor.redactSecrets(in: raw))
        XCTAssertEqual(LogRedactor.hashedUID(sampleUID), FormaLogRedactor.hashedUID(sampleUID))
        XCTAssertEqual(LogRedactor.secretRedactedPlaceholder, FormaLogRedactor.secretPlaceholder)
    }
}
