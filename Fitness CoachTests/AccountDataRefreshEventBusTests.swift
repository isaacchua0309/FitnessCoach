//
//  AccountDataRefreshEventBusTests.swift
//  Fitness CoachTests
//
//  Forma — Account data refresh event bus tests (Phase 5).
//

import Combine
import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountDataRefreshEventBusTests: XCTestCase {

    private let ownerUID = "user-a"
    private let otherUID = "user-b"
    private let referenceDate = ProfileTestFixtures.referenceDate

    func testPublishCoalescesDomainsForSameUID() async {
        let bus = AccountDataRefreshEventBus(
            coalesceInterval: .milliseconds(50),
            nowProvider: { self.referenceDate }
        )
        var received: [AccountDataRefreshEvent] = []
        let cancellable = bus.events.sink { received.append($0) }

        bus.publish(
            AccountDataRefreshEvent(
                uid: ownerUID,
                domains: [.today],
                reason: .realtimeSnapshot,
                createdAt: referenceDate
            )
        )
        bus.publish(
            AccountDataRefreshEvent(
                uid: ownerUID,
                domains: [.coachContext],
                reason: .realtimeSnapshot,
                createdAt: referenceDate
            )
        )
        bus.flushImmediately()

        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.domains, [.today, .coachContext])
        cancellable.cancel()
    }

    func testFilterForCurrentAccountUIDIgnoresOtherAccounts() async {
        let bus = AccountDataRefreshEventBus(nowProvider: { self.referenceDate })
        var received: [AccountDataRefreshEvent] = []
        let cancellable = bus.events
            .filterForCurrentAccountUID { self.ownerUID }
            .sink { received.append($0) }

        bus.publish(
            AccountDataRefreshEvent(
                uid: otherUID,
                domains: [.today],
                reason: .appForeground,
                createdAt: referenceDate
            )
        )
        bus.publish(
            AccountDataRefreshEvent(
                uid: ownerUID,
                domains: [.journey],
                reason: .appForeground,
                createdAt: referenceDate
            )
        )
        bus.flushImmediately()

        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.uid, ownerUID)
        XCTAssertEqual(received.first?.domains, [.journey])
        cancellable.cancel()
    }

    func testDomainMappingUsesPullCountsWithoutSensitivePayload() {
        let summary = CrossDeviceSyncSummary(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh,
            status: .completed,
            startedAt: referenceDate,
            endedAt: referenceDate,
            uploadedMutations: 0,
            pulledDailyLogs: 0,
            pulledFoodEntries: 2,
            pulledWaterEntries: 0,
            pulledWeightEntries: 0,
            pulledDailyReviews: 0,
            pulledProfile: false,
            inserted: 1,
            updated: 0,
            deleted: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            didRefreshUI: false,
            userFacingMessage: nil
        )

        let domains = AccountDataRefreshEventSupport.domains(
            uploadedMutations: 0,
            pullSummary: summary
        )

        XCTAssertEqual(domains, [.food, .today, .coachContext])
    }

    func testFilterForDomainDeliversOnlyMatchingSubscribers() async {
        let bus = AccountDataRefreshEventBus(nowProvider: { self.referenceDate })
        var planEvents = 0
        let cancellable = bus.events
            .filterForDomain(.plan)
            .sink { _ in planEvents += 1 }

        bus.publish(
            AccountDataRefreshEvent(
                uid: ownerUID,
                domains: [.today, .coachContext],
                reason: .manualPullToRefresh,
                createdAt: referenceDate
            )
        )
        bus.publish(
            AccountDataRefreshEvent(
                uid: ownerUID,
                domains: [.profile, .plan],
                reason: .manualPullToRefresh,
                createdAt: referenceDate
            )
        )
        bus.flushImmediately()

        XCTAssertEqual(planEvents, 1)
        cancellable.cancel()
    }
}
