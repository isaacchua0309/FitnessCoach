//
//  CoachMealPhotoPipeline.swift
//  Fitness Coach
//
//  Forma — Meal photo analysis gating and shared Coach copy (compression lives in CoachImagePipeline).
//

import Combine
import Foundation

enum CoachMealPhotoPipeline {

    static let defaultAnalysisPrompt =
        "Analyze this meal photo. Estimate food name, portion, calories, and macros."
    static let userMessageLabel = "Meal photo"

    /// Client wiring is complete when image bytes can reach `photoFoodAnalysis`.
    static var isClientPipelineReady: Bool { FormaAbTest.Coach.mealPhotoPipelineReady }

    static let photoAnalysisIntentResult = CoachIntentResult(
        intent: .logFood,
        confidence: 1,
        domain: .nutrition,
        requiresAppMutation: true,
        requiresUserContext: false,
        canAnswerWithCheapModel: true,
        requiresEscalation: false,
        reason: "Meal photo selected"
    )

    static func hasImagePayload(_ data: Data?) -> Bool {
        guard let data, !data.isEmpty else { return false }
        return true
    }

    static func assertImagePayloadPresent(_ data: Data, file: StaticString = #file, line: UInt = #line) {
        #if DEBUG
        assert(hasImagePayload(data), "photoFoodAnalysis requires non-empty JPEG payload", file: file, line: line)
        #endif
    }
}
