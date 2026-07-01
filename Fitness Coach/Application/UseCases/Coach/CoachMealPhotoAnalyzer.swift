//
//  CoachMealPhotoAnalyzer.swift
//  Fitness Coach
//
//  Meal photo preparation, tracing, and AI food-estimate routing.
//

import Foundation

@MainActor
final class CoachMealPhotoAnalyzer {

    private let aiCommandParsingEnabled: Bool
    private let aiContextBuilder: CoachContextBuilder?
    private let routeHandler: CoachAIRouteHandler

    init(
        aiCommandParsingEnabled: Bool,
        aiContextBuilder: CoachContextBuilder?,
        routeHandler: CoachAIRouteHandler
    ) {
        self.aiCommandParsingEnabled = aiCommandParsingEnabled
        self.aiContextBuilder = aiContextBuilder
        self.routeHandler = routeHandler
    }

    func prepareJPEG(from rawData: Data) -> Result<Data, CoachMealPhotoError> {
        CoachMealPhotoPipeline.prepareJPEG(from: rawData)
    }

    func analyze(
        jpegData: Data,
        recentMessages: [ChatMessage]
    ) async -> CoachActionResult {
        guard aiCommandParsingEnabled, let aiContextBuilder else {
            return .message(CoachResponseBuilder.backendUnavailableResponse)
        }
        return await performAnalysis(
            jpegData: jpegData,
            recentMessages: recentMessages,
            aiContextBuilder: aiContextBuilder
        )
    }

    private func performAnalysis(
        jpegData: Data,
        recentMessages: [ChatMessage],
        aiContextBuilder: CoachContextBuilder
    ) async -> CoachActionResult {
        FormaPipelineTracer.event(
            stage: .coachSend,
            level: .info,
            message: "Meal photo analysis started",
            fields: [
                "jpegBytes": String(jpegData.count),
                "hasImagePayload": String(CoachMealPhotoPipeline.hasImagePayload(jpegData))
            ]
        )

        let context = aiContextBuilder.makeContext(recentMessages: recentMessages)
        let routed = RoutedAITask(
            task: .photoFoodAnalysis(
                imageData: jpegData,
                prompt: CoachMealPhotoPipeline.defaultAnalysisPrompt
            ),
            tier: .cheap,
            intentResult: CoachMealPhotoPipeline.photoAnalysisIntentResult
        )

        do {
            return try await routeHandler.handleAITask(routed, context: context)
        } catch let error as AIServiceError {
            return .message(CoachResponseBuilder.mealPhotoAnalysisFailed(error))
        } catch {
            return .message(CoachResponseBuilder.mealPhotoAnalysisFailed(
                AIServiceError.requestFailed(error.localizedDescription)
            ))
        }
    }
}
