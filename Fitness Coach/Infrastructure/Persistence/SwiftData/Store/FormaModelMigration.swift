//
//  FormaModelMigration.swift
//  Fitness Coach
//
//  SwiftData schema versions and lightweight migration plan.
//

import Foundation
import SwiftData

enum FormaSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            UserProfileEntity.self,
            DailyLogEntity.self,
            FoodEntryEntity.self,
            WaterEntryEntity.self,
            WeightEntryEntity.self,
            WorkoutEntryEntity.self,
            ExerciseSetEntity.self,
            DailyReviewEntity.self,
            WeeklyReviewEntity.self,
            ChatMessageEntity.self,
            DebugRecordEntity.self
        ]
    }
}

enum FormaSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            UserProfileEntity.self,
            DailyLogEntity.self,
            FoodEntryEntity.self,
            WaterEntryEntity.self,
            WeightEntryEntity.self,
            WorkoutEntryEntity.self,
            ExerciseSetEntity.self,
            DailyReviewEntity.self
        ]
    }
}

enum FormaSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            UserProfileEntity.self,
            DailyLogEntity.self,
            FoodEntryEntity.self,
            WaterEntryEntity.self,
            WeightEntryEntity.self,
            DailyReviewEntity.self
        ]
    }
}

enum FormaSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            UserProfileEntity.self,
            DailyLogEntity.self,
            FoodEntryEntity.self,
            WaterEntryEntity.self,
            WeightEntryEntity.self,
            DailyReviewEntity.self
        ]
    }
}

enum FormaSchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            UserProfileEntity.self,
            DailyLogEntity.self,
            FoodEntryEntity.self,
            WaterEntryEntity.self,
            WeightEntryEntity.self,
            DailyReviewEntity.self,
            CoachTimelineEventEntity.self
        ]
    }
}

enum FormaSchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            UserProfileEntity.self,
            DailyLogEntity.self,
            FoodEntryEntity.self,
            WaterEntryEntity.self,
            WeightEntryEntity.self,
            DailyReviewEntity.self,
            CoachTimelineEventEntity.self,
            CoachChatTranscriptMessageEntity.self
        ]
    }
}

enum FormaSchemaV7: VersionedSchema {
    static var versionIdentifier = Schema.Version(7, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            UserProfileEntity.self,
            DailyLogEntity.self,
            FoodEntryEntity.self,
            WaterEntryEntity.self,
            WeightEntryEntity.self,
            DailyReviewEntity.self,
            CoachTimelineEventEntity.self,
            CoachChatTranscriptMessageEntity.self
        ]
    }
}

enum FormaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            FormaSchemaV1.self,
            FormaSchemaV2.self,
            FormaSchemaV3.self,
            FormaSchemaV4.self,
            FormaSchemaV5.self,
            FormaSchemaV6.self,
            FormaSchemaV7.self
        ]
    }

    static var stages: [MigrationStage] {
        [
            MigrationStage.lightweight(
                fromVersion: FormaSchemaV1.self,
                toVersion: FormaSchemaV2.self
            ),
            MigrationStage.lightweight(
                fromVersion: FormaSchemaV2.self,
                toVersion: FormaSchemaV3.self
            ),
            MigrationStage.lightweight(
                fromVersion: FormaSchemaV3.self,
                toVersion: FormaSchemaV4.self
            ),
            MigrationStage.lightweight(
                fromVersion: FormaSchemaV4.self,
                toVersion: FormaSchemaV5.self
            ),
            MigrationStage.lightweight(
                fromVersion: FormaSchemaV5.self,
                toVersion: FormaSchemaV6.self
            ),
            MigrationStage.lightweight(
                fromVersion: FormaSchemaV6.self,
                toVersion: FormaSchemaV7.self
            )
        ]
    }
}
