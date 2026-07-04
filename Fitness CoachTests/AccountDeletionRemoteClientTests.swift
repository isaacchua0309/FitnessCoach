//
//  AccountDeletionRemoteClientTests.swift
//  Fitness CoachTests
//
//  Remote account deletion HTTP client contract regressions (no live network).
//

import XCTest
@testable import Fitness_Coach

final class AccountDeletionRemoteClientTests: XCTestCase {

    private let productionBaseURL = URL(
        string: "https://us-central1-fitness-coach-732fd.cloudfunctions.net/accountDataDeletion"
    )!

    override func tearDown() {
        AccountDeletionMockURLProtocol.reset()
        super.tearDown()
    }

    func testDeleteRemoteAccountDataComposesGatewayURL() async throws {
        AccountDeletionMockURLProtocol.responseBody = Self.validSuccessResponseData

        let client = makeClient(baseURL: productionBaseURL)
        _ = try await client.deleteRemoteAccountData(confirmation: "DELETE")

        let requestURL = try XCTUnwrap(AccountDeletionMockURLProtocol.capturedRequest?.url)
        XCTAssertEqual(
            requestURL.absoluteString,
            "https://us-central1-fitness-coach-732fd.cloudfunctions.net/accountDataDeletion/v1/account/delete-data"
        )
    }

    func testRequestIncludesAuthorizationAndOnlyConfirmationBody() async throws {
        AccountDeletionMockURLProtocol.responseBody = Self.validSuccessResponseData

        let client = AccountDeletionRemoteClient(
            baseURL: productionBaseURL,
            urlSession: makeMockSession(),
            authTokenProvider: { "firebase-test-token" }
        )

        _ = try await client.deleteRemoteAccountData(confirmation: "DELETE")

        let captured = try XCTUnwrap(AccountDeletionMockURLProtocol.capturedRequest)
        XCTAssertEqual(captured.value(forHTTPHeaderField: "Authorization"), "Bearer firebase-test-token")
        XCTAssertEqual(captured.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let bodyData = try XCTUnwrap(captured.httpBody)
        let bodyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        )
        XCTAssertEqual(bodyObject["confirmation"] as? String, "DELETE")
        XCTAssertNil(bodyObject["uid"])
        XCTAssertNil(bodyObject["userId"])
        XCTAssertEqual(bodyObject.keys.sorted(), ["confirmation"])
    }

    func testDecodesSuccessfulBackendResponse() async throws {
        AccountDeletionMockURLProtocol.responseBody = Self.validSuccessResponseData

        let client = makeClient(baseURL: productionBaseURL)
        let result = try await client.deleteRemoteAccountData(confirmation: "DELETE")

        XCTAssertEqual(
            result,
            RemoteAccountDeletionResult(
                uid: "user-a",
                profileDeleted: true,
                dailyLogsDeleted: 2,
                foodEntriesDeleted: 3,
                waterEntriesDeleted: 1,
                weightEntriesDeleted: 1,
                dailyReviewsDeleted: 1,
                syncMetadataDeleted: true,
                healthSummariesDeleted: true
            )
        )
    }

    func testMapsMissingAuthTokenToUnauthenticated() async {
        AccountDeletionMockURLProtocol.responseBody = Self.validSuccessResponseData

        let client = AccountDeletionRemoteClient(
            baseURL: productionBaseURL,
            urlSession: makeMockSession(),
            authTokenProvider: { throw AuthManagerError.notSignedIn }
        )

        do {
            _ = try await client.deleteRemoteAccountData(confirmation: "DELETE")
            XCTFail("Expected unauthenticated error")
        } catch {
            XCTAssertEqual(error as? AccountDeletionRemoteError, .unauthenticated)
        }

        XCTAssertNil(AccountDeletionMockURLProtocol.capturedRequest?.httpBody)
    }

    func testMapsMissingTokenToReauthenticationRequired() async {
        AccountDeletionMockURLProtocol.responseBody = Self.validSuccessResponseData

        let client = AccountDeletionRemoteClient(
            baseURL: productionBaseURL,
            urlSession: makeMockSession(),
            authTokenProvider: { throw AuthManagerError.missingToken }
        )

        do {
            _ = try await client.deleteRemoteAccountData(confirmation: "DELETE")
            XCTFail("Expected reauthenticationRequired error")
        } catch {
            XCTAssertEqual(error as? AccountDeletionRemoteError, .reauthenticationRequired)
        }
    }

    func testMapsHTTP401ToUnauthenticated() async {
        AccountDeletionMockURLProtocol.responseStatusCode = 401
        AccountDeletionMockURLProtocol.responseBody = Data(
            #"{"error":"Invalid Firebase ID token.","backendErrorCategory":"authentication"}"#.utf8
        )

        let client = makeClient(baseURL: productionBaseURL)

        do {
            _ = try await client.deleteRemoteAccountData(confirmation: "DELETE")
            XCTFail("Expected unauthenticated error")
        } catch {
            XCTAssertEqual(error as? AccountDeletionRemoteError, .unauthenticated)
        }
    }

    func testMapsHTTP503ToServerUnavailable() async {
        AccountDeletionMockURLProtocol.responseStatusCode = 503
        AccountDeletionMockURLProtocol.responseBody = Data(
            #"{"ok":false,"uid":"user-a","deleted":{"profile":true,"dailyLogs":0,"foodEntries":0,"waterEntries":0,"weightEntries":0,"dailyReviews":0,"syncMetadata":false,"healthDaily":0,"healthWorkouts":0,"healthRecovery":0,"healthWeeklyReviews":0,"healthSyncMetadata":false},"backendErrorCategory":"timeout"}"#.utf8
        )

        let client = makeClient(baseURL: productionBaseURL)

        do {
            _ = try await client.deleteRemoteAccountData(confirmation: "DELETE")
            XCTFail("Expected serverUnavailable error")
        } catch {
            XCTAssertEqual(error as? AccountDeletionRemoteError, .serverUnavailable)
        }
    }

    func testMapsTransportTimeoutToTimeout() async {
        AccountDeletionMockURLProtocol.responseError = URLError(.timedOut)

        let client = makeClient(baseURL: productionBaseURL)

        do {
            _ = try await client.deleteRemoteAccountData(confirmation: "DELETE")
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertEqual(error as? AccountDeletionRemoteError, .timeout)
        }
    }

    func testMapsOfflineTransportError() async {
        AccountDeletionMockURLProtocol.responseError = URLError(.notConnectedToInternet)

        let client = makeClient(baseURL: productionBaseURL)

        do {
            _ = try await client.deleteRemoteAccountData(confirmation: "DELETE")
            XCTFail("Expected offline error")
        } catch {
            XCTAssertEqual(error as? AccountDeletionRemoteError, .offline)
        }
    }

    func testInMemoryClientCanFakeSuccessAndFailure() async throws {
        let inMemory = InMemoryAccountDeletionRemoteClient()

        await inMemory.configure(
            result: RemoteAccountDeletionResult(
                uid: "user-a",
                profileDeleted: true,
                dailyLogsDeleted: 1,
                foodEntriesDeleted: 1,
                waterEntriesDeleted: 0,
                weightEntriesDeleted: 0,
                dailyReviewsDeleted: 0,
                syncMetadataDeleted: true,
                healthSummariesDeleted: false
            )
        )

        let success = try await inMemory.deleteRemoteAccountData(confirmation: "DELETE")
        XCTAssertEqual(success.uid, "user-a")
        XCTAssertEqual(await inMemory.lastConfirmation, "DELETE")

        await inMemory.reset()
        await inMemory.configure(error: .permissionDenied)

        do {
            _ = try await inMemory.deleteRemoteAccountData(confirmation: "DELETE")
            XCTFail("Expected permissionDenied error")
        } catch {
            XCTAssertEqual(error as? AccountDeletionRemoteError, .permissionDenied)
        }
    }
}

private extension AccountDeletionRemoteClientTests {

    func makeMockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AccountDeletionMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    func makeClient(baseURL: URL) -> AccountDeletionRemoteClient {
        AccountDeletionRemoteClient(
            baseURL: baseURL,
            urlSession: makeMockSession(),
            authTokenProvider: { "firebase-test-token" }
        )
    }

    static let validSuccessResponseData = Data(
        """
        {"ok":true,"uid":"user-a","deleted":{"profile":true,"dailyLogs":2,"foodEntries":3,"waterEntries":1,"weightEntries":1,"dailyReviews":1,"syncMetadata":true,"healthDaily":1,"healthWorkouts":0,"healthRecovery":0,"healthWeeklyReviews":0,"healthSyncMetadata":false}}
        """.utf8
    )
}

private final class AccountDeletionMockURLProtocol: URLProtocol {

    static var capturedRequest: URLRequest?
    static var responseStatusCode = 200
    static var responseBody = Data()
    static var responseError: Error?

    static func reset() {
        capturedRequest = nil
        responseStatusCode = 200
        responseBody = Data()
        responseError = nil
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.capturedRequest = request

        if let responseError = Self.responseError {
            client?.urlProtocol(self, didFailWithError: responseError)
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.responseStatusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
