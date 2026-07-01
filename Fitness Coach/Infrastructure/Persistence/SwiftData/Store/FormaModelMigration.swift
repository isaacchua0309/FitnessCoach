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

enum FormaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [FormaSchemaV1.self, FormaSchemaV2.self, FormaSchemaV3.self]
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
            )
        ]
    }
}
