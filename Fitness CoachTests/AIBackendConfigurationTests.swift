//
//  AIBackendConfigurationTests.swift
//  Fitness CoachTests
//
//  Hosted AI gateway URL resolution — no localhost paths in app wiring.
//

import XCTest
@testable import Fitness_Coach

final class AIBackendConfigurationTests: XCTestCase {

    func testBackendURLNilWhenEnvironmentMissing() {
        XCTAssertNil(AIBackendConfiguration.backendURL(environment: [:]))
        XCTAssertEqual(
            AIBackendConfiguration.unavailableReason(environment: [:]),
            .releaseBackendNotConfigured
        )
    }

    func testBackendURLNilWhenEnvironmentEmpty() {
        let environment = [AIBackendConfiguration.environmentVariableName: "   "]
        XCTAssertNil(AIBackendConfiguration.backendURL(environment: environment))
    }

    func testBackendURLRejectsLocalhost127() {
        let environment = [
            AIBackendConfiguration.environmentVariableName: "http://127.0.0.1:8787"
        ]
        XCTAssertNil(AIBackendConfiguration.backendURL(environment: environment))
        XCTAssertEqual(
            AIBackendConfiguration.unavailableReason(environment: environment),
            .releaseBackendURLRejectedLocalhost
        )
    }

    func testBackendURLRejectsLocalhostHostname() {
        let environment = [
            AIBackendConfiguration.environmentVariableName: "http://localhost:8787"
        ]
        XCTAssertNil(AIBackendConfiguration.backendURL(environment: environment))
        XCTAssertTrue(
            AIBackendConfiguration.isLocalhostURL(
                URL(string: environment[AIBackendConfiguration.environmentVariableName]!)!
            )
        )
    }

    func testBackendURLAcceptsProductionGateway() {
        let environment = [
            AIBackendConfiguration.environmentVariableName: AIBackendConfiguration.productionGatewayURLString
        ]
        XCTAssertEqual(
            AIBackendConfiguration.backendURL(environment: environment)?.absoluteString,
            AIBackendConfiguration.productionGatewayURLString
        )
    }

    func testBackendURLAcceptsExplicitProductionHost() {
        let environment = [
            AIBackendConfiguration.environmentVariableName: "https://ai.forma.example.com"
        ]
        XCTAssertEqual(
            AIBackendConfiguration.backendURL(environment: environment)?.absoluteString,
            "https://ai.forma.example.com"
        )
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
