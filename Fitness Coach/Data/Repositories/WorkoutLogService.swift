//
//  WorkoutLogService.swift
//  Fitness Coach
//
//  Legacy SwiftData service for on-device manual workout entries.
//
//  Official training insights come from Apple Health (`HealthTrainingService`,
//  `TrainingInsightsModel`). This service remains for historical rows, daily-log
//  rollups, and tests until a schema migration retires manual workout storage.
//

import Foundation
import SwiftData

@MainActor
final class WorkoutLogService {

    private let store: SwiftDataStore
    private let dailyLogService: DailyLogService
    private let userProfileService: UserProfileService

    init(
        store: SwiftDataStore,
        dailyLogService: DailyLogService,
        userProfileService: UserProfileService
    ) {
        self.store = store
        self.dailyLogService = dailyLogService
        self.userProfileService = userProfileService
    }

    // MARK: Read

    func getWorkouts(for date: Date) throws -> [WorkoutEntry] {
        guard let log = try dailyLogService.dailyLogEntity(for: date) else {
            return []
        }
        return log.workoutEntries
            .sorted { $0.createdAt < $1.createdAt }
            .map { $0.toModel() }
    }

    func getWorkoutHistory(days: Int) throws -> [WorkoutEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -max(days, 0), to: Date()) ?? Date.distantPast
        let descriptor = FetchDescriptor<WorkoutEntryEntity>(
            predicate: #Predicate { $0.createdAt >= cutoff },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try store.fetch(descriptor).map { $0.toModel() }
    }
}
