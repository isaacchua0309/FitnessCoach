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

    func parseCommand(_ text: String, context: AIContext) async throws -> AIParsedCommand {
        let request = AIParseCommandRequest(text: text, context: context)

        let response: AIParseCommandResponse
        do {
            response = try await llmClient.parseCommand(request: request)
        } catch let error as LLMClientError {
            throw AICommandParser.map(error)
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
        case .invalidStatusCode(let code):
            if code == 401 {
                return .authenticationFailed
            }
            return .backendUnavailable
        case .decodingFailed(let message):
            return .decodingFailed(message)
        case .authenticationFailed:
            return .authenticationFailed
        }
    }
}
