//
//  AccountSyncMutationCoalescingTests.swift
//  Fitness CoachTests
//
//  Forma — Pure coalescing rule tests for account sync outbox (Phase 3).
//

import XCTest
@testable import Fitness_Coach

final class AccountSyncMutationCoalescingTests: XCTestCase {

    private let ownerUID = "user-abc"
    private let entityId = "food-entry-1"
    private let referenceDate = FormaSwiftDataMigrationTestSupport.referenceDate

    func testNeverCoalescesAcrossEntityTypes() {
        let foodUpsert = makeEntity(entityType: .foodEntry, operation: .upsert)
        let result = AccountSyncMutationCoalescing.apply(
            to: [foodUpsert],
            incoming: request(entityType: .waterEntry, operation: .upsert),
            remoteMayExist: false,
            now: referenceDate
        )

        guard case .persisted(let mutation) = result else {
            return XCTFail("Expected persisted water upsert.")
        }
        XCTAssertEqual(mutation.entityType, .waterEntry)
        XCTAssertEqual(foodUpsert.status, .pending)
    }

    func testNeverCoalescesAcrossOwnerUID() {
        let otherOwnerUpsert = AccountSyncMutationEntity(
            id: "mutation-1",
            ownerUID: "other-user",
            entityType: .foodEntry,
            entityId: entityId,
            localDate: "2026-07-04",
            operation: .upsert,
            payloadVersion: 1,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )

        let result = AccountSyncMutationCoalescing.apply(
            to: [otherOwnerUpsert],
            incoming: request(operation: .upsert),
            remoteMayExist: false,
            now: referenceDate
        )

        guard case .persisted(let mutation) = result else {
            return XCTFail("Expected persisted upsert for primary owner.")
        }
        XCTAssertEqual(mutation.ownerUID, ownerUID)
        XCTAssertEqual(otherOwnerUpsert.status, .pending)
    }

    // MARK: - Helpers

    private func request(
        entityType: AccountSyncEntityType = .foodEntry,
        operation: AccountSyncOperation,
        mutationGroupId: String? = nil
    ) -> AccountSyncMutationRequest {
        AccountSyncMutationRequest(
            ownerUID: ownerUID,
            entityType: entityType,
            entityId: entityId,
            localDate: "2026-07-04",
            operation: operation,
            mutationGroupId: mutationGroupId
        )
    }

    private func makeEntity(
        entityType: AccountSyncEntityType = .foodEntry,
        operation: AccountSyncOperation
    ) -> AccountSyncMutationEntity {
        AccountSyncMutationEntity(
            id: UUID().uuidString,
            ownerUID: ownerUID,
            entityType: entityType,
            entityId: entityId,
            localDate: "2026-07-04",
            operation: operation,
            payloadVersion: 1,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
    }
}
