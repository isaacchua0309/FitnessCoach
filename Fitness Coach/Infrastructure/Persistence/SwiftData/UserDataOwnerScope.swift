//
//  UserDataOwnerScope.swift
//  Fitness Coach
//
//  Forma — Repository-facing shim over `UserDataOwnership` (Phase 1).
//

import Foundation

@MainActor
protocol UserDataNutritionOwnershipEntity: AnyObject {
    var ownerUID: String? { get set }
    var localUpdatedAt: Date? { get set }
    var entitySchemaVersion: Int { get set }
}

@MainActor
protocol UserDataCoachOwnershipEntity: AnyObject {
    var userId: String? { get set }
    var localUpdatedAt: Date? { get set }
    var entitySchemaVersion: Int { get set }
}

extension UserProfileEntity: UserDataNutritionOwnershipEntity {}
extension DailyLogEntity: UserDataNutritionOwnershipEntity {}
extension FoodEntryEntity: UserDataNutritionOwnershipEntity {}
extension WaterEntryEntity: UserDataNutritionOwnershipEntity {}
extension WeightEntryEntity: UserDataNutritionOwnershipEntity {}
extension DailyReviewEntity: UserDataNutritionOwnershipEntity {}
extension CoachTimelineEventEntity: UserDataCoachOwnershipEntity {}
extension CoachChatTranscriptMessageEntity: UserDataCoachOwnershipEntity {}

/// Centralizes UID scoping for nutrition and related local user data (Phase 1).
enum UserDataOwnerScope {

    /// UID stamped on new rows at write time. Nil when the session is unsigned.
    static func ownerUIDForNewWrite(sessionUID: String?) -> String? {
        sessionUID
    }

    /// Whether a persisted row is visible to the current session.
    static func isVisible(entityOwnerUID: String?, sessionUID: String?) -> Bool {
        UserDataOwnership.canRead(ownerUID: entityOwnerUID, currentUID: sessionUID)
    }

    /// Resolves a non-empty UID for user-data writes.
    static func requiredSessionUID(_ sessionUID: String?, operation: String) throws -> String {
        try UserDataOwnership.requireUID(sessionUID, operation: operation)
    }

    static func stampNewNutritionWrite(
        on entity: some UserDataNutritionOwnershipEntity,
        ownerUID: String,
        now: Date = Date()
    ) {
        entity.ownerUID = ownerUID
        entity.localUpdatedAt = now
        entity.entitySchemaVersion = UserDataEntitySchema.currentEntitySchemaVersion
    }

    static func touchNutritionWrite(
        on entity: some UserDataNutritionOwnershipEntity,
        now: Date = Date()
    ) {
        entity.localUpdatedAt = now
    }

    static func stampNewCoachWrite(
        on entity: some UserDataCoachOwnershipEntity,
        userId: String,
        now: Date = Date()
    ) {
        entity.userId = userId
        entity.localUpdatedAt = now
        entity.entitySchemaVersion = UserDataEntitySchema.currentEntitySchemaVersion
    }

    static func touchCoachWrite(
        on entity: some UserDataCoachOwnershipEntity,
        now: Date = Date()
    ) {
        entity.localUpdatedAt = now
    }

    /// Ensures a daily log belongs to the active account before attaching child rows.
    static func requireMatchingDailyLogOwner(
        _ dailyLog: DailyLogEntity,
        sessionUID: String
    ) throws {
        guard let ownerUID = dailyLog.ownerUID else {
            throw ServiceError.invalidInput("Daily log is not associated with the current account.")
        }
        guard ownerUID == sessionUID else {
            throw ServiceError.invalidInput("Daily log belongs to a different account.")
        }
    }
}
