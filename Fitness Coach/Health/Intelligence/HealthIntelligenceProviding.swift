//
//  HealthIntelligenceProviding.swift
//  Fitness Coach
//
//  Forma — Protocol contracts for Health Intelligence engines and context assembly.
//

import Foundation

// MARK: - Context

protocol HealthIntelligenceContextBuilding: Sendable {
    func buildContext(for targetDate: Date, calendar: Calendar) async -> HealthIntelligenceContext
}

extension HealthIntelligenceContextBuilding {
    func buildContext(for targetDate: Date) async -> HealthIntelligenceContext {
        await buildContext(for: targetDate, calendar: .current)
    }
}

// MARK: - Baselines

protocol HealthBaselineProviding: Sendable {
    func buildContext(for targetDate: Date, calendar: Calendar) async -> HealthBaselineContext
}

extension HealthBaselineProviding {
    func buildContext(for targetDate: Date) async -> HealthBaselineContext {
        await buildContext(for: targetDate, calendar: .current)
    }
}

// MARK: - Engines

protocol TrainingLoadProviding: Sendable {
    func evaluate(_ input: TrainingLoadEngineInput) throws -> TrainingLoadSummary
}

protocol WorkoutIntelligenceProviding: Sendable {
    func evaluate(_ input: WorkoutIntelligenceInput) throws -> WorkoutSummary
}

protocol RecoveryEngineProviding: Sendable {
    func evaluate(_ input: RecoveryEngineInput) throws -> RecoverySummary
}

protocol AdaptiveNutritionProviding: Sendable {
    func evaluate(_ input: AdaptiveNutritionEngineInput) throws -> AdaptiveNutritionSummary
}

protocol NextBestActionProviding: Sendable {
    func evaluate(_ input: NextBestActionEngineInput) throws -> NextBestAction
}

protocol WeeklyReviewProviding: Sendable {
    func evaluate(_ input: WeeklyReviewEngineInput) throws -> WeeklyHealthReview?
}

// MARK: - Dependencies

struct HealthIntelligenceEngineDependencies: Sendable {
    var trainingLoad: any TrainingLoadProviding
    var workout: any WorkoutIntelligenceProviding
    var recovery: any RecoveryEngineProviding
    var adaptiveNutrition: any AdaptiveNutritionProviding
    var nextBestAction: any NextBestActionProviding
    var weeklyReview: any WeeklyReviewProviding

    static func production(
        trainingLoad: any TrainingLoadProviding = TrainingLoadEngine(),
        workout: any WorkoutIntelligenceProviding = WorkoutIntelligenceEngine(),
        recovery: any RecoveryEngineProviding = RecoveryEngine(),
        adaptiveNutrition: any AdaptiveNutritionProviding = AdaptiveNutritionEngine(),
        nextBestAction: any NextBestActionProviding = HealthNextBestActionEngine(),
        weeklyReview: any WeeklyReviewProviding = WeeklyReviewEngine()
    ) -> HealthIntelligenceEngineDependencies {
        HealthIntelligenceEngineDependencies(
            trainingLoad: trainingLoad,
            workout: workout,
            recovery: recovery,
            adaptiveNutrition: adaptiveNutrition,
            nextBestAction: nextBestAction,
            weeklyReview: weeklyReview
        )
    }
}
