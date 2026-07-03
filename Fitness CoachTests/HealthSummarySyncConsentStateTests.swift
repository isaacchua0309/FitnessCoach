//
//  HealthSummarySyncConsentStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthSummarySyncConsentStateTests: XCTestCase {

    func testDefaultConsentIsNotDeterminedAndDisallowsRemoteSync() {
        let state = HealthSummarySyncConsentState.default

        XCTAssertEqual(state.decision, .notDetermined)
        XCTAssertFalse(state.isRemoteSyncAllowed)
        XCTAssertFalse(state.hasExplicitDecision)
    }

    func testOptedInAllowsRemoteSyncWhenCapabilityEnabled() {
        let state = HealthSummarySyncConsentState(decision: .optedIn, updatedAt: Date())

        XCTAssertTrue(state.isRemoteSyncAllowed)
        XCTAssertTrue(
            HealthSummaryRemoteSyncGate.isActive(
                consent: state,
                featureFlagEnabled: true
            )
        )
    }

    func testOptedOutBlocksRemoteSyncEvenWhenCapabilityEnabled() {
        let state = HealthSummarySyncConsentState(decision: .optedOut, updatedAt: Date())

        XCTAssertFalse(state.isRemoteSyncAllowed)
        XCTAssertFalse(
            HealthSummaryRemoteSyncGate.isActive(
                consent: state,
                featureFlagEnabled: true
            )
        )
    }

    func testCapabilityDisabledBlocksRemoteSyncEvenWhenOptedIn() {
        let state = HealthSummarySyncConsentState(decision: .optedIn, updatedAt: Date())

        XCTAssertFalse(
            HealthSummaryRemoteSyncGate.isActive(
                consent: state,
                featureFlagEnabled: false
            )
        )
    }
}

final class HealthSummarySyncConsentStoreTests: XCTestCase {

    private let userProvider = StaticHealthCacheUserProvider(userID: "user-123")
    private var storage: LockedHealthSummarySyncConsentStore!

    override func setUp() {
        super.setUp()
        storage = LockedHealthSummarySyncConsentStore()
    }

    @MainActor
    func testStoreDefaultsToNotDetermined() {
        let store = HealthSummarySyncConsentStore(storage: storage, userProvider: userProvider)

        XCTAssertEqual(store.state.decision, .notDetermined)
    }

    @MainActor
    func testOptInPersistsForCurrentUser() {
        let store = HealthSummarySyncConsentStore(storage: storage, userProvider: userProvider)

        store.optIn()

        XCTAssertEqual(store.state.decision, .optedIn)
        XCTAssertEqual(storage.load(for: "user-123").decision, .optedIn)
    }

    @MainActor
    func testOptOutPersistsForCurrentUser() {
        let store = HealthSummarySyncConsentStore(storage: storage, userProvider: userProvider)
        store.optIn()

        store.optOut()

        XCTAssertEqual(store.state.decision, .optedOut)
        XCTAssertEqual(storage.load(for: "user-123").decision, .optedOut)
    }

    @MainActor
    func testRefreshLoadsStoredDecision() {
        storage.save(
            HealthSummarySyncConsentState(decision: .optedIn, updatedAt: Date()),
            for: "user-123"
        )
        let store = HealthSummarySyncConsentStore(storage: storage, userProvider: userProvider)

        store.refresh()

        XCTAssertEqual(store.state.decision, .optedIn)
    }

    func testResolverRequiresOptInAndCapability() {
        storage.save(
            HealthSummarySyncConsentState(decision: .optedIn, updatedAt: Date()),
            for: "user-123"
        )

        XCTAssertTrue(
            HealthSummarySyncConsentResolver.isRemoteSyncActive(
                storage: storage,
                userProvider: userProvider,
                featureFlagEnabled: true
            )
        )
        XCTAssertFalse(
            HealthSummarySyncConsentResolver.isRemoteSyncActive(
                storage: storage,
                userProvider: userProvider,
                featureFlagEnabled: false
            )
        )
    }
}

final class HealthSummarySyncConsentCopyTests: XCTestCase {

    func testConsentCopyMentionsNormalizedSummariesAndNoRawSamples() {
        let message = FormaProductCopy.Settings.AppleHealth.RemoteSync.Consent.enableMessage.lowercased()

        XCTAssertTrue(message.contains("normalized health summaries"))
        XCTAssertTrue(message.contains("does not upload raw apple health samples"))
        XCTAssertTrue(message.contains("workout summaries"))
        XCTAssertTrue(message.contains("recovery"))
        XCTAssertTrue(message.contains("weekly review"))
    }
}
