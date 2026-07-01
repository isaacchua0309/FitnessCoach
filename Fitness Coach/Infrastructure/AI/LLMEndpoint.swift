//
//  LLMEndpoint.swift
//  Fitness Coach
//
//  FitPilot AI — Logical endpoints exposed by the backend AI gateway.
//

import Foundation

enum LLMEndpoint: String, Codable, Equatable, Sendable {
    case classifyCoachIntent = "v1/ai/classify-coach-intent"
    case parseCommand = "v1/ai/parse-command"
    case estimateFood = "v1/ai/estimate-food"
    case mealAdvice = "v1/ai/generate-meal-advice"
    case dailyReview = "v1/ai/generate-daily-review"
    case parseWorkout = "v1/ai/parse-workout"
    case parseEditDelete = "v1/ai/parse-edit-delete"
    case parseMultiAction = "v1/ai/parse-multi-action"
}
