//
//  ReleaseAIBackendConfigurationTests.swift
//  Fitness CoachTests
//
//  Release AI backend URL resolution — no localhost defaults in production wiring.
//

import XCTest
@testable import Fitness_Coach

final class ReleaseAIBackendConfigurationTests: XCTestCase {

    func testReleaseBackendURLNilWhenEnvironmentMissing() {
        XCTAssertNil(ReleaseAIBackendConfiguration.releaseBackendURL(environment: [:]))
        XCTAssertEqual(
            ReleaseAIBackendConfiguration.unavailableReason(environment: [:]),
            .releaseBackendNotConfigured
        )
    }

    func testReleaseBackendURLNilWhenEnvironmentEmpty() {
        let environment = [ReleaseAIBackendConfiguration.environmentVariableName: "   "]
        XCTAssertNil(ReleaseAIBackendConfiguration.releaseBackendURL(environment: environment))
    }

    func testReleaseBackendURLRejectsLocalhost127() {
        let environment = [
            ReleaseAIBackendConfiguration.environmentVariableName: "http://127.0.0.1:8787"
        ]
        XCTAssertNil(ReleaseAIBackendConfiguration.releaseBackendURL(environment: environment))
        XCTAssertEqual(
            ReleaseAIBackendConfiguration.unavailableReason(environment: environment),
            .releaseBackendURLRejectedLocalhost
        )
    }

    func testReleaseBackendURLRejectsLocalhostHostname() {
        let environment = [
            ReleaseAIBackendConfiguration.environmentVariableName: "http://localhost:8787"
        ]
        XCTAssertNil(ReleaseAIBackendConfiguration.releaseBackendURL(environment: environment))
        XCTAssertTrue(
            ReleaseAIBackendConfiguration.isLocalhostURL(
                URL(string: environment[ReleaseAIBackendConfiguration.environmentVariableName]!)!
            )
        )
    }

    func testReleaseBackendURLAcceptsExplicitProductionHost() {
        let environment = [
            ReleaseAIBackendConfiguration.environmentVariableName: "https://ai.forma.example.com"
        ]
        XCTAssertEqual(
            ReleaseAIBackendConfiguration.releaseBackendURL(environment: environment)?.absoluteString,
            "https://ai.forma.example.com"
        )
    }

    func testDebugBackendURLUsesEnvironmentOverride() {
        let environment = [
            LocalAIBackendConfiguration.environmentVariableName: "http://192.168.0.42:8787"
        ]
        XCTAssertEqual(
            LocalAIBackendConfiguration.debugBackendURL(environment: environment)?.absoluteString,
            "http://192.168.0.42:8787"
        )
    }

    func testDebugBackendURLDoesNotDefaultToLocalhostOnDeviceWhenUnset() {
        #if !targetEnvironment(simulator)
        XCTAssertNil(LocalAIBackendConfiguration.debugBackendURL(environment: [:]))
        #endif
    }

    func testUnavailableLLMClientFailsFastWithoutMockAnswers() async {
        let client = UnavailableLLMClient(reason: .releaseBackendNotConfigured)
        let request = AIParseCommandRequest(
            text: "log water",
            context: AIContext(date: Date(timeIntervalSince1970: 0), timezoneIdentifier: "UTC")
        )

        do {
            _ = try await client.parseCommand(request: request)
            XCTFail("Expected missing configuration.")
        } catch let error as LLMClientError {
            XCTAssertEqual(error, .missingConfiguration)
            XCTAssertEqual(AICommandParser.map(error), .backendUnavailable)
            XCTAssertEqual(
                AIServiceError.backendUnavailable.userMessage,
                FormaProductCopy.Error.coachUnavailable
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
