//
//  CoachMealPhotoAnalyzer.swift
//  Fitness Coach
//
//  Meal photo preparation, tracing, and AI food-estimate routing.
//

import Foundation

struct MealPhotoAnalysisOutcome: Equatable {
    var result: CoachActionResult
    var sessionResult: ImageAnalysisSessionResult?
    var errorMessage: String?
    var errorCategory: String?
}

@MainActor
final class CoachMealPhotoAnalyzer {

    private let aiCommandParsingEnabled: Bool
    private let contextPacketBuilder: CoachContextPacketV2Builder?
    private let routeHandler: CoachAIRouteHandler

    init(
        aiCommandParsingEnabled: Bool,
        contextPacketBuilder: CoachContextPacketV2Builder?,
        routeHandler: CoachAIRouteHandler
    ) {
        self.aiCommandParsingEnabled = aiCommandParsingEnabled
        self.contextPacketBuilder = contextPacketBuilder
        self.routeHandler = routeHandler
    }

    func analyze(
        session: ImageAnalysisSession,
        recommission: ImageAnalysisRecommissionContext? = nil,
        recentMessages: [ChatMessage],
        context preparedContext: CoachContextPacketV2? = nil,
        currentUserMessage: String? = nil
    ) async -> MealPhotoAnalysisOutcome {
        guard aiCommandParsingEnabled, let contextPacketBuilder else {
            let error = AIServiceError.backendUnavailable
            CoachImageAnalysisDebugLogger.logError(error)
            return MealPhotoAnalysisOutcome(
                result: .message(CoachResponseBuilder.backendUnavailableResponse),
                errorMessage: error.userMessage,
                errorCategory: CoachImageAnalysisDebugLogFormatter.errorCategory(for: error)
            )
        }

        let prompt: String
        if let recommission {
            prompt = ImageAnalysisPromptBuilder.recommissionMessage(
                session: session,
                clarification: recommission.clarification
            )
        } else {
            prompt = ImageAnalysisPromptBuilder.initialPrompt(caption: session.userCaption)
        }

        return await performAnalysis(
            jpegData: session.originalImageAttachment.imageJPEG,
            prompt: prompt,
            recommission: recommission,
            recentMessages: recentMessages,
            preparedContext: preparedContext,
            currentUserMessage: currentUserMessage,
            userCaption: session.userCaption
        )
    }

    private func performAnalysis(
        jpegData: Data,
        prompt: String,
        recommission: ImageAnalysisRecommissionContext?,
        recentMessages: [ChatMessage],
        preparedContext: CoachContextPacketV2?,
        currentUserMessage: String?,
        userCaption: String
    ) async -> MealPhotoAnalysisOutcome {
        FormaPipelineTracer.event(
            stage: .coachSend,
            level: .info,
            message: "Meal photo analysis started",
            fields: [
                "jpegBytes": String(jpegData.count),
                "hasImagePayload": String(CoachMealPhotoPipeline.hasImagePayload(jpegData)),
                "isRecommission": String(recommission != nil)
            ]
        )

        let context: CoachContextPacketV2
        if let preparedContext {
            context = preparedContext
        } else {
            context = await contextPacketBuilder!.makeContext(
                recentMessages: recentMessages,
                currentUserMessage: currentUserMessage
            )
        }

        let uploadAttachment = CoachMealImageUploadAttachment.fromUploadData(jpegData)

        do {
            let presentation = try await routeHandler.analyzeMealPhoto(
                uploadAttachment: uploadAttachment,
                prompt: prompt,
                recommission: recommission,
                context: context,
                userCaption: userCaption
            )
            return MealPhotoAnalysisOutcome(
                result: presentation.actionResult,
                sessionResult: presentation.sessionResult
            )
        } catch let error as AIServiceError {
            let message = CoachResponseBuilder.mealPhotoAnalysisFailed(error)
            CoachImageAnalysisDebugLogger.logError(error)
            return MealPhotoAnalysisOutcome(
                result: .message(message),
                errorMessage: message,
                errorCategory: CoachImageAnalysisDebugLogFormatter.errorCategory(for: error)
            )
        } catch {
            let wrapped = AIServiceError.requestFailed(error.localizedDescription)
            let message = CoachResponseBuilder.mealPhotoAnalysisFailed(wrapped)
            CoachImageAnalysisDebugLogger.logError(wrapped)
            return MealPhotoAnalysisOutcome(
                result: .message(message),
                errorMessage: message,
                errorCategory: CoachImageAnalysisDebugLogFormatter.errorCategory(for: wrapped)
            )
        }
    }
}
