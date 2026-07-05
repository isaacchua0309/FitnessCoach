//
//  CoachTodayContextCoordinator.swift
//  Fitness Coach
//
//  Forma — Coach empty-state today context assembly.
//

import Foundation

@MainActor
final class CoachTodayContextCoordinator {

    private let actionCenter: FitnessActionCenter
    private let dailyLogReader: any DailyLogReading
    private let weightLogReader: (any WeightLogReading)?
    private let healthActivityQuery: HealthActivityQueryService
    private let contextPacketCoordinator: CoachContextPacketCoordinator
    private let healthIntelligenceLoadEnabled: () -> Bool
    private let trainingInsightsStore: TrainingInsightsStore?

    init(
        actionCenter: FitnessActionCenter,
        dailyLogReader: any DailyLogReading,
        weightLogReader: (any WeightLogReading)?,
        healthActivityQuery: HealthActivityQueryService,
        contextPacketCoordinator: CoachContextPacketCoordinator,
        healthIntelligenceLoadEnabled: @escaping () -> Bool,
        trainingInsightsStore: TrainingInsightsStore?
    ) {
        self.actionCenter = actionCenter
        self.dailyLogReader = dailyLogReader
        self.weightLogReader = weightLogReader
        self.healthActivityQuery = healthActivityQuery
        self.contextPacketCoordinator = contextPacketCoordinator
        self.healthIntelligenceLoadEnabled = healthIntelligenceLoadEnabled
        self.trainingInsightsStore = trainingInsightsStore
    }

    func refreshTodayContext() async -> CoachTodayContextState? {
        do {
            let dailyLog = try dailyLogReader.getTodayLog()
            let activity = await contextPacketCoordinator.resolveAIActivityContext(for: dailyLog.date)
            let latestWeight = dailyLog.weightKg == nil ? try weightLogReader?.getLatestWeight() : nil
            let weightLogged = (dailyLog.weightKg ?? latestWeight?.weightKg) != nil
            let integration = trainingInsightsStore?.integrationState ?? .connected
            let dataSource = trainingInsightsStore?.dataSource ?? .appleHealth
            let latestFoodEntry = try? actionCenter.getFoodEntries(for: dailyLog.date).last
            let stepsFromHealth: Int?
            if activity.stepsOverride == nil, dailyLog.steps == nil {
                stepsFromHealth = try? await healthActivityQuery.stepsToday(on: dailyLog.date)
            } else {
                stepsFromHealth = nil
            }
            let resolvedSteps = activity.stepsOverride ?? dailyLog.steps ?? stepsFromHealth
            let healthNote = CoachTodayContextBuilder.healthActivityNote(
                trainingDataSource: dataSource,
                trainingIntegration: integration
            )

            return CoachTodayContextBuilder.build(
                dailyLog: dailyLog,
                latestFoodEntry: latestFoodEntry,
                weightLogged: weightLogged,
                hasWorkout: activity.hasWorkoutToday,
                steps: resolvedSteps,
                healthActivityNote: healthNote,
                healthIntelligence: activity.healthIntelligence,
                healthIntelligenceAwarenessAvailable: activity.healthIntelligenceAwarenessAvailable,
                isCoachContextEnabled: healthIntelligenceLoadEnabled(),
                trainingIntegration: integration,
                trainingDataSource: dataSource
            )
        } catch {
            return nil
        }
    }
}
