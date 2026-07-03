//
//  AICommandParser.swift
//  Fitness Coach
//
//  FitPilot AI — Parses user text into a structured AIParsedCommand.
//
//  This is a thin coordinator over the LLM client. It validates output but never
//  mutates state or calls app services.
//

import Foundation

struct AICommandParser {

    private let llmClient: LLMClient

    init(llmClient: LLMClient) {
        self.llmClient = llmClient
    }

    func parseCommand(_ text: String, context: CoachContextPacketV2) async throws -> AIParsedCommand {
        let request = AIParseCommandRequest(text: text, context: context)

        let response: AIParseCommandResponse
        do {
            response = try await llmClient.parseCommand(request: request)
        } catch let error as LLMClientError {
            throw Self.map(error)
        } catch {
            throw AIServiceError.requestFailed(error.localizedDescription)
        }

        let command = response.parsedCommand
        if case .invalid(let reason) = AIResponseValidator.validate(command) {
            throw AIServiceError.validationFailed(reason)
        }
        return command
    }

    static func map(_ error: LLMClientError) -> AIServiceError {
        switch error {
        case .invalidURL, .missingConfiguration, .backendUnavailable:
            return .backendUnavailable
        case .requestTimedOut:
            return .requestTimedOut
        case .requestFailed:
            return .backendUnavailable
        case .networkUnavailable:
            return .networkUnavailable
        case .payloadTooLarge:
            return .payloadTooLarge
        case .backendRejected(let message):
            if isImageRejection(message) {
                return .backendRejectedImage
            }
            return .parsingFailed(message ?? "Request rejected.")
        case .rateLimited:
            return .backendUnavailable
        case .modelUnavailable:
            return .modelUnavailable
        case .invalidStatusCode(let code):
            return mapStatusCode(code)
        case .decodingFailed(let message):
            return .decodingFailed(message)
        case .authenticationFailed:
            return .authenticationFailed
        }
    }

    static func mapFoodEstimate(_ error: LLMClientError) -> AIServiceError {
        switch error {
        case .decodingFailed(let message):
            return .invalidNutritionJSON(message)
        case .backendRejected(let message):
            if isNutritionExtractionFailure(message) {
                return .invalidNutritionJSON(message ?? "Photo estimate rejected.")
            }
            if isImageRejection(message) {
                return .backendRejectedImage
            }
            return .invalidNutritionJSON(message ?? "Photo estimate rejected.")
        case .invalidStatusCode(let code) where code == 422:
            return .invalidNutritionJSON("Nutrition extraction failed validation.")
        case .invalidStatusCode(let code) where code == 400:
            return .backendRejectedImage
        default:
            return map(error)
        }
    }

    private static func mapStatusCode(_ code: Int) -> AIServiceError {
        switch code {
        case 401:
            return .authenticationFailed
        case 413:
            return .payloadTooLarge
        case 400:
            return .parsingFailed("Request rejected.")
        case 422:
            return .invalidNutritionJSON("Nutrition extraction failed validation.")
        case 429:
            return .backendUnavailable
        case 500...599:
            return .modelUnavailable
        default:
            return .backendUnavailable
        }
    }

    private static func isImageRejection(_ message: String?) -> Bool {
        guard let message else { return false }
        let lowered = message.lowercased()
        return lowered.contains("imagejpegbase64") ||
            lowered.contains("image/jpeg") ||
            lowered.contains("invalid image") ||
            lowered.contains("missing or invalid image")
    }

    private static func isNutritionExtractionFailure(_ message: String?) -> Bool {
        guard let message else { return false }
        let lowered = message.lowercased()
        return lowered.contains("nutrition") || lowered.contains("extract")
    }
}
