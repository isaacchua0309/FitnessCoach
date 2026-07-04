//
//  AccountSyncMutationEntity.swift
//  Fitness Coach
//
//  Forma — Durable sync outbox mutation row (Phase 3).
//

import Foundation
import SwiftData

@Model
final class AccountSyncMutationEntity {

    @Attribute(.unique) var id: String
    var ownerUID: String
    var entityTypeRawValue: String
    var entityId: String
    var localDate: String?
    var operationRawValue: String
    var payloadVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var attemptCount: Int
    var nextRetryAt: Date?
    var lastError: String?
    var statusRawValue: String
    var mutationGroupId: String?

    init(
        id: String,
        ownerUID: String,
        entityType: AccountSyncEntityType,
        entityId: String,
        localDate: String?,
        operation: AccountSyncOperation,
        payloadVersion: Int,
        createdAt: Date,
        updatedAt: Date,
        attemptCount: Int = 0,
        nextRetryAt: Date? = nil,
        lastError: String? = nil,
        status: AccountSyncMutationStatus = .pending,
        mutationGroupId: String? = nil
    ) {
        self.id = id
        self.ownerUID = ownerUID
        self.entityTypeRawValue = entityType.rawValue
        self.entityId = entityId
        self.localDate = localDate
        self.operationRawValue = operation.rawValue
        self.payloadVersion = payloadVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.attemptCount = attemptCount
        self.nextRetryAt = nextRetryAt
        self.lastError = lastError
        self.statusRawValue = status.rawValue
        self.mutationGroupId = mutationGroupId
    }
}

extension AccountSyncMutationEntity {

    var entityType: AccountSyncEntityType {
        get { AccountSyncEntityType(rawValue: entityTypeRawValue) ?? .foodEntry }
        set { entityTypeRawValue = newValue.rawValue }
    }

    var operation: AccountSyncOperation {
        get { AccountSyncOperation(rawValue: operationRawValue) ?? .upsert }
        set { operationRawValue = newValue.rawValue }
    }

    var status: AccountSyncMutationStatus {
        get { AccountSyncMutationStatus(rawValue: statusRawValue) ?? .pending }
        set { statusRawValue = newValue.rawValue }
    }

    var key: AccountSyncMutationKey {
        AccountSyncMutationKey(ownerUID: ownerUID, entityType: entityType, entityId: entityId)
    }

    func toModel() -> AccountSyncMutation {
        AccountSyncMutation(
            id: id,
            ownerUID: ownerUID,
            entityType: entityType,
            entityId: entityId,
            localDate: localDate,
            operation: operation,
            createdAt: createdAt,
            attemptCount: attemptCount
        )
    }
}
