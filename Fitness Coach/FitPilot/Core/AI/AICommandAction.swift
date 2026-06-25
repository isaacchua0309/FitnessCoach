//
//  AICommandAction.swift
//  Fitness Coach
//
//  FitPilot AI — A single structured action proposed by the AI boundary.
//
//  This uses a struct representation (instead of an enum with associated
//  values) so it decodes cleanly from JSON. Drafts are proposals only; they are
//  validated and executed by services elsewhere, never by the AI layer.
//

import Foundation

enum AICommandActionType: String, Codable, Equatable, Sendable {
    case logFood
    case logWater
    case logWeight
    case logWorkout
    case startNewDay
    case mealAdvice
    case status
    case dailyReview
}

struct AICommandAction: Codable, Equatable, Sendable {
    var type: AICommandActionType
    var foodDraft: FoodDraft?
    var waterDraft: WaterDraft?
    var weightDraft: WeightDraft?
    var workoutDraft: WorkoutDraft?
    var startNewDayWeightKg: Double?
    var adviceQuestion: String?

    init(
        type: AICommandActionType,
        foodDraft: FoodDraft? = nil,
        waterDraft: WaterDraft? = nil,
        weightDraft: WeightDraft? = nil,
        workoutDraft: WorkoutDraft? = nil,
        startNewDayWeightKg: Double? = nil,
        adviceQuestion: String? = nil
    ) {
        self.type = type
        self.foodDraft = foodDraft
        self.waterDraft = waterDraft
        self.weightDraft = weightDraft
        self.workoutDraft = workoutDraft
        self.startNewDayWeightKg = startNewDayWeightKg
        self.adviceQuestion = adviceQuestion
    }
}
