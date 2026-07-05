//
//  AIDependencies.swift
//  Fitness Coach
//
//  LLM client and AIService construction for AppContainer.
//  See Docs/Architecture/DependencyInjectionMap.md
//

import Foundation

extension AppContainer {

    struct AIBundle {
        let llmClient: LLMClient
        let aiService: AIService
        let aiCommandParsingEnabled: Bool
        #if DEBUG
        let wiring: (clientType: String, baseURL: URL?, authAttached: Bool)
        #endif
    }

    static func buildAI(
        session: AuthDependenciesBundle,
        inMemory: Bool
    ) -> AIBundle {
        #if DEBUG
        let wiring: (clientType: String, baseURL: URL?, authAttached: Bool)
        #endif

        let authManager = session.authManager
        let llmClient: LLMClient
        if inMemory {
            llmClient = MockLLMClient()
            #if DEBUG
            wiring = ("MockLLMClient", nil, false)
            #endif
        } else if let backendURL = AIBackendConfiguration.backendURL() {
            llmClient = FallbackLLMClient(
                primary: FormaAIBackendClient(
                    baseURL: backendURL,
                    authTokenProvider: { try await authManager.idToken() }
                )
            )
            #if DEBUG
            wiring = ("FallbackLLMClient+FormaAIBackendClient", backendURL, true)
            #endif
        } else {
            llmClient = UnavailableLLMClient(
                reason: AIBackendConfiguration.unavailableReason()
            )
            #if DEBUG
            wiring = ("UnavailableLLMClient", nil, false)
            #endif
        }

        #if DEBUG
        return AIBundle(
            llmClient: llmClient,
            aiService: AIService(llmClient: llmClient),
            aiCommandParsingEnabled: FormaAbTest.Coach.aiCommandParsingEnabled,
            wiring: wiring
        )
        #else
        return AIBundle(
            llmClient: llmClient,
            aiService: AIService(llmClient: llmClient),
            aiCommandParsingEnabled: FormaAbTest.Coach.aiCommandParsingEnabled
        )
        #endif
    }
}
