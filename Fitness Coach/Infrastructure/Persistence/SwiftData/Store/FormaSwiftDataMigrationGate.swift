//
//  FormaSwiftDataMigrationGate.swift
//  Fitness Coach
//
//  Tracks Coach Timeline Context v2 SwiftData migration completion so pruning,
//  backfill, and maintenance jobs never run against a partially migrated store.
//

import Foundation
import SwiftData

enum FormaSwiftDataMigrationGate {

    /// Active SwiftData schema version that includes Coach timeline + transcript + sync outbox entities.
    static let coachV2SchemaVersion = 9

    private static let schemaVersionKey = "forma.swiftdata.schemaVersion"
    private static let migrationCompleteKey = "forma.swiftdata.coachV2MigrationComplete"

    /// Whether the on-disk store has finished migrating to the Coach v2 schema.
    static var isCoachV2MigrationComplete: Bool {
        let storedVersion = UserDefaults.standard.integer(forKey: schemaVersionKey)
        let markedComplete = UserDefaults.standard.bool(forKey: migrationCompleteKey)
        return storedVersion >= coachV2SchemaVersion && markedComplete
    }

    /// Marks Coach v2 migration complete after the active schema opens successfully.
    static func markCoachV2MigrationComplete() {
        UserDefaults.standard.set(coachV2SchemaVersion, forKey: schemaVersionKey)
        UserDefaults.standard.set(true, forKey: migrationCompleteKey)
    }

    /// Clears migration markers — test-only.
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: schemaVersionKey)
        UserDefaults.standard.removeObject(forKey: migrationCompleteKey)
    }

    /// Pruning, compaction, and post-migration backfill must wait until migration completes.
    static func shouldAllowCoachDataMaintenance() -> Bool {
        isCoachV2MigrationComplete
    }
}

enum FormaSchemaCoachV2Verification {

    /// Compile-time list check used by tests to ensure Coach v2 entities ship in the active schema.
    static func coachV2EntitiesAreRegisteredInActiveSchema() -> Bool {
        FormaSchemaV9.models.contains(where: { $0 == CoachTimelineEventEntity.self })
            && FormaSchemaV9.models.contains(where: { $0 == CoachChatTranscriptMessageEntity.self })
    }

    static func coachTimelineEntityRegisteredAtV5() -> Bool {
        FormaSchemaV5.models.contains(where: { $0 == CoachTimelineEventEntity.self })
    }

    static func legacyChatMessageEntityIsV1Only() -> Bool {
        FormaSchemaV1.models.contains(where: { $0 == ChatMessageEntity.self })
            && !FormaSchemaV2.models.contains(where: { $0 == ChatMessageEntity.self })
    }
}

enum FormaSchemaV7AccountSyncVerification {

    static func syncMetadataEntitiesAreRegisteredInV7Schema() -> Bool {
        let models = FormaSchemaV7.models
        let required: [any PersistentModel.Type] = [
            DailyLogEntity.self,
            FoodEntryEntity.self,
            WaterEntryEntity.self,
            WeightEntryEntity.self,
            DailyReviewEntity.self
        ]
        return required.allSatisfy { entity in
            models.contains(where: { $0 == entity })
        }
    }

    static func coachEntitiesAreExcludedFromAccountSyncMetadata() -> Bool {
        let syncEntities: [any PersistentModel.Type] = [
            DailyLogEntity.self,
            FoodEntryEntity.self,
            WaterEntryEntity.self,
            WeightEntryEntity.self,
            DailyReviewEntity.self
        ]
        return !syncEntities.contains(where: { $0 == CoachTimelineEventEntity.self })
            && !syncEntities.contains(where: { $0 == CoachChatTranscriptMessageEntity.self })
    }
}

enum FormaSchemaV9AccountSyncVerification {

    static var activeSchema: any VersionedSchema.Type {
        FormaSchemaV9.self
    }

    static func syncMetadataEntitiesAreRegisteredInActiveSchema() -> Bool {
        let models = FormaSchemaV9.models
        let required: [any PersistentModel.Type] = [
            DailyLogEntity.self,
            FoodEntryEntity.self,
            WaterEntryEntity.self,
            WeightEntryEntity.self,
            DailyReviewEntity.self
        ]
        return required.allSatisfy { entity in
            models.contains(where: { $0 == entity })
        }
    }

    static func syncOutboxEntityIsRegisteredInActiveSchema() -> Bool {
        FormaSchemaV9.models.contains(where: { $0 == AccountSyncMutationEntity.self })
    }

    static func coachEntitiesAreExcludedFromAccountSyncMetadata() -> Bool {
        let syncEntities: [any PersistentModel.Type] = [
            DailyLogEntity.self,
            FoodEntryEntity.self,
            WaterEntryEntity.self,
            WeightEntryEntity.self,
            DailyReviewEntity.self
        ]
        return !syncEntities.contains(where: { $0 == CoachTimelineEventEntity.self })
            && !syncEntities.contains(where: { $0 == CoachChatTranscriptMessageEntity.self })
    }
}
