//
//  TrainingIntegrationTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class TrainingIntegrationTests: XCTestCase {

    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "TrainingIntegrationTests")!
        userDefaults.removePersistentDomain(forName: "TrainingIntegrationTests")
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "TrainingIntegrationTests")
        userDefaults = nil
        super.tearDown()
    }

    func testDefaultHealthTrainingServiceIsNotConnectedOnIOS() async {
        let authorizer = MockHealthKitTrainingAuthorizing(status: .notDetermined)
        let service = HealthTrainingService(authorizer: authorizer, userDefaults: userDefaults)

        #if os(iOS)
        XCTAssertEqual(service.dataSource, .appleHealth)
        XCTAssertTrue(service.isHealthDataAvailable)
        XCTAssertEqual(service.authorizationStatus(), .notDetermined)
        let refreshed = await service.refreshState()
        XCTAssertEqual(refreshed, .notConnected)
        #else
        let unavailable = MockHealthKitTrainingAuthorizing(isHealthDataAvailable: false, status: .unavailable)
        let unavailableService = HealthTrainingService(authorizer: unavailable, userDefaults: userDefaults)
        XCTAssertEqual(unavailableService.dataSource, .unavailable)
        XCTAssertFalse(unavailableService.isHealthDataAvailable)
        let unavailableState = await unavailableService.refreshState()
        XCTAssertEqual(unavailableState, .unavailable)
        #endif
    }

    func testHealthTrainingServiceMapsAuthorizedToConnected() async {
        let authorizer = MockHealthKitTrainingAuthorizing(status: .sharingAuthorized)
        let service = HealthTrainingService(authorizer: authorizer, userDefaults: userDefaults)

        XCTAssertEqual(service.authorizationStatus(), .sharingAuthorized)
        let connected = await service.refreshState()
        XCTAssertEqual(connected, .connected)
    }

    func testHealthTrainingServiceMapsDeniedStatus() async {
        let authorizer = MockHealthKitTrainingAuthorizing(status: .sharingDenied)
        let service = HealthTrainingService(authorizer: authorizer, userDefaults: userDefaults)

        let denied = await service.refreshState()
        XCTAssertEqual(denied, .denied)
    }

    func testHealthTrainingServiceRequestAuthorization() async {
        let authorizer = MockHealthKitTrainingAuthorizing(
            status: .notDetermined,
            requestResult: .sharingAuthorized
        )
        let service = HealthTrainingService(authorizer: authorizer, userDefaults: userDefaults)

        let state = await service.requestConnection()

        XCTAssertEqual(state, .connected)
        XCTAssertEqual(authorizer.requestCallCount, 1)
    }

    func testHealthTrainingServiceUnavailableDevice() async {
        let authorizer = MockHealthKitTrainingAuthorizing(isHealthDataAvailable: false)
        let service = HealthTrainingService(authorizer: authorizer, userDefaults: userDefaults)

        let refreshed = await service.refreshState()
        let requested = await service.requestConnection()
        XCTAssertEqual(refreshed, .unavailable)
        XCTAssertEqual(requested, .unavailable)
    }

    func testHealthTrainingServiceStubConnectedFlag() async {
        let authorizer = MockHealthKitTrainingAuthorizing(status: .notDetermined)
        let service = HealthTrainingService(authorizer: authorizer, userDefaults: userDefaults)
        service.setStubConnected(true)

        XCTAssertEqual(service.authorizationStatus(), .sharingAuthorized)
        let connected = await service.refreshState()
        XCTAssertEqual(connected, .connected)

        service.resetStubFlags()
        let reset = await service.refreshState()
        XCTAssertEqual(reset, .notConnected)
    }

    func testHealthTrainingServiceStubDeniedFlag() async {
        let authorizer = MockHealthKitTrainingAuthorizing(status: .notDetermined)
        let service = HealthTrainingService(authorizer: authorizer, userDefaults: userDefaults)
        service.setStubDenied(true)

        let denied = await service.refreshState()
        XCTAssertEqual(denied, .denied)
    }

    func testTrainingInsightsStoreRefreshUpdatesPublishedState() async {
        let provider = StubTrainingIntegrationProvider(
            refreshResult: .connected
        )
        let store = TrainingInsightsStore(integration: provider)

        await store.refresh()

        XCTAssertEqual(store.integrationState, .connected)
        XCTAssertEqual(store.dataSource, .appleHealth)
        XCTAssertEqual(provider.refreshCallCount, 1)
    }

    func testTrainingInsightsStoreConnectSetsRequestingThenResult() async {
        let provider = StubTrainingIntegrationProvider(
            refreshResult: .notConnected,
            requestConnectionResult: .connected
        )
        let store = TrainingInsightsStore(integration: provider)

        await store.connectAppleHealth()

        XCTAssertEqual(store.integrationState, .connected)
        XCTAssertEqual(provider.requestConnectionCallCount, 1)
    }

    func testIntegrationStateGateFlags() {
        XCTAssertTrue(TrainingIntegrationState.notConnected.showsConnectionGate)
        XCTAssertTrue(TrainingIntegrationState.denied.showsConnectionGate)
        XCTAssertTrue(TrainingIntegrationState.failed(message: "x").showsConnectionGate)
        XCTAssertFalse(TrainingIntegrationState.connected.showsConnectionGate)
        XCTAssertTrue(TrainingIntegrationState.connected.isConnected)
    }

    func testTrainingIntegrationCopyGateMessages() {
        XCTAssertEqual(
            TrainingIntegrationCopy.gateMessage(for: .notConnected),
            TrainingIntegrationCopy.lockedBody
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.gateTitle(for: .notConnected),
            TrainingIntegrationCopy.lockedTitle
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.connectButtonTitle(for: .notConnected),
            TrainingIntegrationCopy.connectAppleHealth
        )
        XCTAssertNil(TrainingIntegrationCopy.connectButtonTitle(for: .connected))
        XCTAssertEqual(
            TrainingIntegrationCopy.gateMessage(for: .denied),
            TrainingIntegrationCopy.deniedMessage
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.gateMessage(for: .unavailable),
            TrainingIntegrationCopy.unavailableMessage
        )
    }

    func testFormaProductCopyTrainingIntegrationAliases() {
        XCTAssertEqual(
            FormaProductCopy.Training.Integration.connectAppleHealth,
            "Connect Apple Health"
        )
        XCTAssertEqual(
            FormaProductCopy.Training.Integration.poweredByAppleFitness,
            "Training insights are powered by Apple Fitness."
        )
    }

    func testPlanAndSettingsIntegrationCopy() {
        XCTAssertEqual(
            TrainingIntegrationCopy.planIntegrationMessage(isAppleHealthConnected: false),
            TrainingIntegrationCopy.planConnectPrompt
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.planIntegrationMessage(isAppleHealthConnected: true),
            TrainingIntegrationCopy.planConnectedNote
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.settingsStatusLabel(for: .connected),
            TrainingIntegrationCopy.settingsStatusConnected
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.settingsStatusLabel(for: .notConnected),
            TrainingIntegrationCopy.settingsStatusNotConnected
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.settingsStatusLabel(for: .denied),
            TrainingIntegrationCopy.settingsStatusAccessDenied
        )
        XCTAssertEqual(
            TrainingIntegrationCopy.settingsStatusLabel(for: .unavailable),
            TrainingIntegrationCopy.settingsStatusUnavailable
        )
    }

    func testAuthorizationStatusIntegrationStateMapping() {
        XCTAssertEqual(HealthTrainingAuthorizationStatus.sharingAuthorized.integrationState, .connected)
        XCTAssertEqual(HealthTrainingAuthorizationStatus.sharingDenied.integrationState, .denied)
        XCTAssertEqual(HealthTrainingAuthorizationStatus.notDetermined.integrationState, .notConnected)
        XCTAssertEqual(HealthTrainingAuthorizationStatus.unavailable.integrationState, .unavailable)
    }
}
