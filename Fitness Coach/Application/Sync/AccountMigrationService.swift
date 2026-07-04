//
//  AccountMigrationService.swift
//  Fitness Coach
//
//  Forma — Safely backfills legacy local user-data ownership (Phase 1).
//

import Foundation
import SwiftData

protocol AccountMigrationRunning: AnyObject {
    func runSafeBackfill(for uid: String) async throws
}

@MainActor
private protocol UserDataBookkeepingPersistable: AnyObject {
    var localUpdatedAt: Date? { get set }
    var entitySchemaVersion: Int { get set }
}

extension UserProfileEntity: UserDataBookkeepingPersistable {}
extension DailyLogEntity: UserDataBookkeepingPersistable {}
extension FoodEntryEntity: UserDataBookkeepingPersistable {}
extension WaterEntryEntity: UserDataBookkeepingPersistable {}
extension WeightEntryEntity: UserDataBookkeepingPersistable {}
extension DailyReviewEntity: UserDataBookkeepingPersistable {}
extension CoachTimelineEventEntity: UserDataBookkeepingPersistable {}
extension CoachChatTranscriptMessageEntity: UserDataBookkeepingPersistable {}

@MainActor
final class AccountMigrationService {

    private let store: SwiftDataStore
    private let userProfileService: UserProfileService
    private let uidProvider: any AccountUIDProviding

    init(
        store: SwiftDataStore,
        userProfileService: UserProfileService,
        uidProvider: any AccountUIDProviding
    ) {
        self.store = store
        self.userProfileService = userProfileService
        self.uidProvider = uidProvider
    }

    /// Evaluates and applies a safe ownership backfill for the active signed-in user.
    @discardableResult
    func runSafeBackfillForCurrentUser() async throws -> AccountMigrationBackfillReport {
        guard let uid = uidProvider.currentUID else {
            AccountMigrationDebugLogger.backfillSkippedMissingUID()
            return .refused(uid: "", reason: "missing_signed_in_uid")
        }
        return try await runSafeBackfill(for: uid)
    }

    /// Evaluates and applies a safe ownership backfill for the provided Firebase UID.
    @discardableResult
    func runSafeBackfill(for uid: String) async throws -> AccountMigrationBackfillReport {
        let evaluation = try evaluateBackfill(for: uid)
        guard evaluation.canBackfill else {
            AccountMigrationDebugLogger.backfillRefused(uid: evaluation.uid, report: evaluation)
            return evaluation
        }

        let applied = try applyBackfill(for: evaluation.uid)
        let report = AccountMigrationBackfillReport(
            uid: evaluation.uid,
            canBackfill: true,
            reason: evaluation.reason,
            dailyLogsUpdated: applied.dailyLogsUpdated,
            foodEntriesUpdated: applied.foodEntriesUpdated,
            waterEntriesUpdated: applied.waterEntriesUpdated,
            weightEntriesUpdated: applied.weightEntriesUpdated,
            dailyReviewsUpdated: applied.dailyReviewsUpdated,
            coachMessagesUpdated: applied.coachMessagesUpdated,
            timelineEventsUpdated: applied.timelineEventsUpdated
        )
        AccountMigrationDebugLogger.backfillAllowed(uid: report.uid, report: report)
        return report
    }

    /// Dry-run evaluation for whether ownership backfill is safe and how many rows would change.
    func evaluateBackfill(for uid: String) throws -> AccountMigrationBackfillReport {
        let normalizedUID = try normalizedUID(uid)
        let safety = try evaluateSafety(for: normalizedUID)
        guard safety.allowed else {
            return .refused(uid: normalizedUID, reason: safety.reason)
        }

        let candidates = try countBackfillCandidates(for: normalizedUID)
        return AccountMigrationBackfillReport(
            uid: normalizedUID,
            canBackfill: true,
            reason: safety.reason,
            dailyLogsUpdated: candidates.dailyLogs,
            foodEntriesUpdated: candidates.foodEntries,
            waterEntriesUpdated: candidates.waterEntries,
            weightEntriesUpdated: candidates.weightEntries,
            dailyReviewsUpdated: candidates.dailyReviews,
            coachMessagesUpdated: candidates.coachMessages,
            timelineEventsUpdated: candidates.timelineEvents
        )
    }

    /// Backfills schema bookkeeping fields that do not assign ownership.
    ///
    /// Safe to call repeatedly on app launch after a schema upgrade.
    func backfillSchemaV7BookkeepingIfNeeded() throws {
        var didChange = false

        for entity in try store.fetch(FetchDescriptor<UserProfileEntity>()) {
            didChange = backfillBookkeeping(on: entity, updatedAt: entity.updatedAt) || didChange
        }
        for entity in try store.fetch(FetchDescriptor<DailyLogEntity>()) {
            didChange = backfillBookkeeping(on: entity, updatedAt: entity.updatedAt) || didChange
        }
        for entity in try store.fetch(FetchDescriptor<FoodEntryEntity>()) {
            didChange = backfillBookkeeping(on: entity, updatedAt: entity.updatedAt) || didChange
        }
        for entity in try store.fetch(FetchDescriptor<WaterEntryEntity>()) {
            didChange = backfillBookkeeping(on: entity, updatedAt: entity.createdAt) || didChange
        }
        for entity in try store.fetch(FetchDescriptor<WeightEntryEntity>()) {
            didChange = backfillBookkeeping(on: entity, updatedAt: entity.createdAt) || didChange
        }
        for entity in try store.fetch(FetchDescriptor<DailyReviewEntity>()) {
            didChange = backfillBookkeeping(on: entity, updatedAt: entity.createdAt) || didChange
        }
        for entity in try store.fetch(FetchDescriptor<CoachTimelineEventEntity>()) {
            didChange = backfillBookkeeping(on: entity, updatedAt: entity.updatedAt) || didChange
        }
        for entity in try store.fetch(FetchDescriptor<CoachChatTranscriptMessageEntity>()) {
            didChange = backfillBookkeeping(on: entity, updatedAt: entity.updatedAt) || didChange
        }

        if didChange {
            try store.save()
        }
    }

    // MARK: - Safety

    private struct BackfillSafety {
        let allowed: Bool
        let reason: String
    }

    private struct BackfillCounts {
        var dailyLogs = 0
        var foodEntries = 0
        var waterEntries = 0
        var weightEntries = 0
        var dailyReviews = 0
        var coachMessages = 0
        var timelineEvents = 0
    }

    private func normalizedUID(_ uid: String) throws -> String {
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.invalidInput("A valid Firebase UID is required for account migration.")
        }
        return trimmed
    }

    private func evaluateSafety(for uid: String) throws -> BackfillSafety {
        switch try userProfileService.currentProfileOwnership(for: uid) {
        case .mismatched:
            return BackfillSafety(
                allowed: false,
                reason: "local_profile_owner_mismatch"
            )
        case .unowned, .matchesSession:
            break
        }

        if try hasForeignOwnedNutritionRows(excluding: uid) {
            return BackfillSafety(
                allowed: false,
                reason: "foreign_owned_nutrition_rows_present"
            )
        }

        if try hasForeignOwnedCoachRows(excluding: uid) {
            return BackfillSafety(
                allowed: false,
                reason: "foreign_owned_coach_rows_present"
            )
        }

        switch try userProfileService.currentProfileOwnership(for: uid) {
        case .unowned:
            return BackfillSafety(allowed: true, reason: "unowned_local_profile")
        case .matchesSession:
            return BackfillSafety(allowed: true, reason: "profile_owner_matches_session")
        case .mismatched:
            return BackfillSafety(allowed: false, reason: "local_profile_owner_mismatch")
        }
    }

    private func hasForeignOwnedNutritionRows(excluding uid: String) throws -> Bool {
        if try store.fetch(FetchDescriptor<DailyLogEntity>()).contains(where: { isForeignOwner($0.ownerUID, excluding: uid) }) {
            return true
        }
        if try store.fetch(FetchDescriptor<FoodEntryEntity>()).contains(where: { isForeignOwner($0.ownerUID, excluding: uid) }) {
            return true
        }
        if try store.fetch(FetchDescriptor<WaterEntryEntity>()).contains(where: { isForeignOwner($0.ownerUID, excluding: uid) }) {
            return true
        }
        if try store.fetch(FetchDescriptor<WeightEntryEntity>()).contains(where: { isForeignOwner($0.ownerUID, excluding: uid) }) {
            return true
        }
        if try store.fetch(FetchDescriptor<DailyReviewEntity>()).contains(where: { isForeignOwner($0.ownerUID, excluding: uid) }) {
            return true
        }
        return false
    }

    private func hasForeignOwnedCoachRows(excluding uid: String) throws -> Bool {
        if try store.fetch(FetchDescriptor<CoachTimelineEventEntity>()).contains(where: { isForeignOwner($0.userId, excluding: uid) }) {
            return true
        }
        if try store.fetch(FetchDescriptor<CoachChatTranscriptMessageEntity>()).contains(where: { isForeignOwner($0.userId, excluding: uid) }) {
            return true
        }
        return false
    }

    private func isForeignOwner(_ ownerUID: String?, excluding uid: String) -> Bool {
        guard let ownerUID else { return false }
        return ownerUID != uid
    }

    private func countBackfillCandidates(for uid: String) throws -> BackfillCounts {
        var counts = BackfillCounts()
        counts.dailyLogs = try store.fetch(FetchDescriptor<DailyLogEntity>()).filter { $0.ownerUID == nil }.count
        counts.foodEntries = try store.fetch(FetchDescriptor<FoodEntryEntity>()).filter { $0.ownerUID == nil }.count
        counts.waterEntries = try store.fetch(FetchDescriptor<WaterEntryEntity>()).filter { $0.ownerUID == nil }.count
        counts.weightEntries = try store.fetch(FetchDescriptor<WeightEntryEntity>()).filter { $0.ownerUID == nil }.count
        counts.dailyReviews = try store.fetch(FetchDescriptor<DailyReviewEntity>()).filter { $0.ownerUID == nil }.count
        counts.coachMessages = try store.fetch(FetchDescriptor<CoachChatTranscriptMessageEntity>()).filter { $0.userId == nil }.count
        counts.timelineEvents = try store.fetch(FetchDescriptor<CoachTimelineEventEntity>()).filter { $0.userId == nil }.count
        _ = uid
        return counts
    }

    @discardableResult
    private func applyBackfill(for uid: String) throws -> BackfillCounts {
        var counts = BackfillCounts()

        for entity in try store.fetch(FetchDescriptor<DailyLogEntity>()) where entity.ownerUID == nil {
            entity.ownerUID = uid
            _ = backfillBookkeeping(on: entity, updatedAt: entity.updatedAt)
            counts.dailyLogs += 1
        }
        for entity in try store.fetch(FetchDescriptor<FoodEntryEntity>()) where entity.ownerUID == nil {
            entity.ownerUID = uid
            _ = backfillBookkeeping(on: entity, updatedAt: entity.updatedAt)
            counts.foodEntries += 1
        }
        for entity in try store.fetch(FetchDescriptor<WaterEntryEntity>()) where entity.ownerUID == nil {
            entity.ownerUID = uid
            _ = backfillBookkeeping(on: entity, updatedAt: entity.createdAt)
            counts.waterEntries += 1
        }
        for entity in try store.fetch(FetchDescriptor<WeightEntryEntity>()) where entity.ownerUID == nil {
            entity.ownerUID = uid
            _ = backfillBookkeeping(on: entity, updatedAt: entity.createdAt)
            counts.weightEntries += 1
        }
        for entity in try store.fetch(FetchDescriptor<DailyReviewEntity>()) where entity.ownerUID == nil {
            entity.ownerUID = uid
            _ = backfillBookkeeping(on: entity, updatedAt: entity.createdAt)
            counts.dailyReviews += 1
        }
        for entity in try store.fetch(FetchDescriptor<CoachTimelineEventEntity>()) where entity.userId == nil {
            entity.userId = uid
            _ = backfillBookkeeping(on: entity, updatedAt: entity.updatedAt)
            counts.timelineEvents += 1
        }
        for entity in try store.fetch(FetchDescriptor<CoachChatTranscriptMessageEntity>()) where entity.userId == nil {
            entity.userId = uid
            _ = backfillBookkeeping(on: entity, updatedAt: entity.updatedAt)
            counts.coachMessages += 1
        }

        if counts.dailyLogs > 0
            || counts.foodEntries > 0
            || counts.waterEntries > 0
            || counts.weightEntries > 0
            || counts.dailyReviews > 0
            || counts.coachMessages > 0
            || counts.timelineEvents > 0 {
            try store.save()
        }

        return counts
    }

    private func backfillBookkeeping<T: UserDataBookkeepingPersistable>(
        on entity: T,
        updatedAt: Date
    ) -> Bool {
        var didChange = false
        if entity.localUpdatedAt == nil {
            entity.localUpdatedAt = updatedAt
            didChange = true
        }
        if entity.entitySchemaVersion < UserDataEntitySchema.currentEntitySchemaVersion {
            entity.entitySchemaVersion = UserDataEntitySchema.currentEntitySchemaVersion
            didChange = true
        }
        return didChange
    }
}

extension AccountMigrationService: AccountMigrationRunning {}
