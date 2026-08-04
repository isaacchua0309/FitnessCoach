//
//  FormaContextLoopIntegrationTests.swift
//  Fitness CoachTests
//
//  Focused Debug ContextLoop host integration checks.
//

import ContextLoopSDK
import XCTest
@testable import Fitness_Coach

final class FormaContextLoopIntegrationTests: XCTestCase {

    @MainActor
    func testReleaseDefaultInvocationFailsClosed() {
        let availability = ContextLoopReporter.availability(
            in: BuildEnvironment(isDebugBuild: false, isInternalBuild: false)
        )
        guard case .unavailable = availability else {
            return XCTFail("Release must be unavailable")
        }
        let result = ContextLoopReporter.invoke(
            in: BuildEnvironment(isDebugBuild: false, isInternalBuild: false)
        )
        guard case .rejected = result else {
            return XCTFail("Release invoke must reject")
        }
    }

#if DEBUG
    @MainActor
    func testDebugInvocationSucceedsWithFixture() async {
        FormaContextLoopIntegration.bootstrap()
        let host = AlphaHostController(
            configStore: AlphaConfigStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        )
        let png = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mNQ2LTqPzGYYVQhfRUCAC22+A0OlLpTAAAAAElFTkSuQmCC"
        )!
        await host.invoke(
            environment: BuildEnvironment(isDebugBuild: true),
            preferredCapturer: FixtureScreenshotCapturer(pngData: png)
        )
        XCTAssertTrue(host.showFlow)
        XCTAssertNil(host.lastRejectionReason)
    }

    @MainActor
    func testReviewMustBeApprovedAndHighRiskBlocks() async {
        let config = AlphaBackendConfiguration(baseURLString: "http://127.0.0.1:8080")
        let coordinator = AlphaSubmitCoordinator(
            configuration: config,
            client: FakeAlphaBackendClient(),
            environment: BuildEnvironment(isDebugBuild: true)
        )
        let unapproved = await coordinator.submit(
            AlphaSubmitInput(
                reviewApproved: false,
                descriptionText: "bug",
                buildIdentity: BuildIdentity(
                    appVersion: "1",
                    buildNumber: "1",
                    environmentName: "debug",
                    gitCommitSHA: "abc"
                )
            )
        )
        XCTAssertEqual(unapproved, .failed)
        XCTAssertEqual(coordinator.lastError, .reviewNotApproved)

        let blocked = await coordinator.submit(
            AlphaSubmitInput(
                reviewApproved: true,
                descriptionText: "token ghp_abcdefghijklmnopqrstuvwxyz0123456789",
                buildIdentity: BuildIdentity(
                    appVersion: "1",
                    buildNumber: "1",
                    environmentName: "debug",
                    gitCommitSHA: "abc"
                )
            )
        )
        XCTAssertEqual(blocked, .blockedByRedaction)
    }

    @MainActor
    func testFormaContextProviderOmitsSensitiveFields() async throws {
        let state = FormaContextLoopProviderState()
        state.currentScreen = "today"
        state.selectedTab = "today"
        state.isAuthenticated = true
        state.hasActivePlan = true
        state.theme = "oceanBlue"
        let provider = FormaSafeContextProvider(state: state)
        let value = try await provider.collect()
        XCTAssertFalse(value.json.contains("Bearer"))
        XCTAssertFalse(value.json.lowercased().contains("email"))
        XCTAssertFalse(value.json.lowercased().contains("healthkit"))
        XCTAssertFalse(value.json.lowercased().contains("prompt"))
        XCTAssertTrue(value.json.contains("authenticated"))
        XCTAssertTrue(value.json.contains("activePlan"))
        XCTAssertTrue(value.json.contains("theme"))
    }

    func testBreadcrumbAndLogBuffersRemainBounded() {
        let rings = ContextLoopRings()
        rings.resetForTests()
        for i in 0..<250 {
            rings.addBreadcrumb(Breadcrumb(name: "b-\(i)"))
            rings.addLog(CuratedLogEntry(level: "info", message: "m-\(i)"))
        }
        let snap = rings.snapshot()
        XCTAssertEqual(snap.breadcrumbs.count, 100)
        XCTAssertEqual(snap.logs.count, 200)
    }

    func testBuildSHAAttachedFromEnvironment() {
        let identity = BuildIdentity.current(
            bundle: .main,
            environment: [
                "CONTEXTLOOP_ENV": "debug",
                "CONTEXTLOOP_GIT_SHA": "deadbeef"
            ]
        )
        XCTAssertEqual(identity.environmentName, "debug")
        XCTAssertEqual(identity.gitCommitSHA, "deadbeef")
        XCTAssertFalse(identity.missingFields.contains("gitCommitSHA"))
    }

    func testReportEndpointFormedOnce() {
        let config = AlphaBackendConfiguration(baseURLString: "http://192.168.1.10:8080")
        XCTAssertEqual(config.createReportsURLString, "http://192.168.1.10:8080/v1/reports")
        XCTAssertNil(config.urlIssue)
    }

    @MainActor
    func testRepeatedInvocationDoesNotDuplicatePresentation() async {
        let host = AlphaHostController(
            configStore: AlphaConfigStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        )
        let png = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mNQ2LTqPzGYYVQhfRUCAC22+A0OlLpTAAAAAElFTkSuQmCC"
        )!
        await host.invoke(
            environment: BuildEnvironment(isDebugBuild: true),
            preferredCapturer: FixtureScreenshotCapturer(pngData: png)
        )
        let first = host.sessionID
        await host.invoke(
            environment: BuildEnvironment(isDebugBuild: true),
            preferredCapturer: FixtureScreenshotCapturer(pngData: png)
        )
        XCTAssertEqual(host.sessionID, first)
        XCTAssertTrue(host.status.contains("already presenting"))
    }

    @MainActor
    func testCancellationLeavesHostUsable() async {
        let host = AlphaHostController(
            configStore: AlphaConfigStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        )
        let png = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAFUlEQVR42mNQ2LTqPzGYYVQhfRUCAC22+A0OlLpTAAAAAElFTkSuQmCC"
        )!
        await host.invoke(
            environment: BuildEnvironment(isDebugBuild: true),
            preferredCapturer: FixtureScreenshotCapturer(pngData: png)
        )
        host.cancelPresentation()
        XCTAssertFalse(host.showFlow)
        XCTAssertNil(host.sessionID)
        await host.invoke(
            environment: BuildEnvironment(isDebugBuild: true),
            preferredCapturer: FixtureScreenshotCapturer(pngData: png)
        )
        XCTAssertTrue(host.showFlow)
    }

    @MainActor
    func testLatestAlphaConfigurationReachesUploaderURL() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = AlphaConfigStore(defaults: defaults)
        store.baseURLString = "http://10.0.0.8:8080"
        store.save()
        switch store.validatedConfiguration() {
        case .success(let config):
            XCTAssertEqual(config.createReportsURLString, "http://10.0.0.8:8080/v1/reports")
        case .failure(let error):
            XCTFail("unexpected \(error)")
        }
    }
#endif
}
