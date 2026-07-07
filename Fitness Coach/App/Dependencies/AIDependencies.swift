//
//  AIDependencies.swift
//  Fitness Coach
//
//  Typed LLM client and AIService bundle for AppContainer wiring.
//

import Foundation

/// Resolved AI client dependencies for `AppContainer`.
struct AIDependencies {
    let llmClient: LLMClient
    let aiService: AIService
    let aiCommandParsingEnabled: Bool
    #if DEBUG
    let wiring: (clientType: String, baseURL: URL?, authAttached: Bool)
    #endif

    static func build(
        session: AuthDependencies,
        inMemory: Bool
    ) -> AIDependencies {
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
        return AIDependencies(
            llmClient: llmClient,
            aiService: AIService(llmClient: llmClient),
            aiCommandParsingEnabled: FormaAbTest.Coach.aiCommandParsingEnabled,
            wiring: wiring
        )
        #else
        return AIDependencies(
            llmClient: llmClient,
            aiService: AIService(llmClient: llmClient),
            aiCommandParsingEnabled: FormaAbTest.Coach.aiCommandParsingEnabled
        )
        #endif
    }
}

#if DEBUG
extension AppContainer {
    static func logAIBackendURLDetection() {
        if let backendURL = AIBackendConfiguration.backendURL() {
            FormaPipelineTracer.event(
                stage: .appWiring,
                level: .info,
                message: "AI gateway URL configured",
                fields: [
                    "detected": "true",
                    "gatewayURL": backendURL.absoluteString
                ]
            )
            return
        }

        switch FormaEnvironment.aiBackendURLDetection() {
        case .notDetected:
            FormaPipelineTracer.event(
                stage: .appWiring,
                level: .info,
                message: "FORMA_AI_BACKEND_URL not detected",
                fields: ["detected": "false"]
            )
        case .detected(let source):
            FormaPipelineTracer.event(
                stage: .appWiring,
                level: .info,
                message: "FORMA_AI_BACKEND_URL rejected or invalid",
                fields: [
                    "detected": "false",
                    "source": source.rawValue
                ]
            )
        }
    }

    static func logLLMClientWiring(clientType: String, baseURL: URL?, authAttached: Bool) {
        var fields: [String: String] = [
            "clientType": clientType,
            "authAttached": String(authAttached),
            "traceEnabled": String(FormaPipelineTracer.isEnabled),
            "traceVerbose": String(FormaPipelineTracer.isVerbose)
        ]
        if let baseURL {
            fields["baseURL"] = baseURL.absoluteString
        }
        FormaPipelineTracer.event(
            stage: .appWiring,
            level: .info,
            message: "LLM client wired",
            fields: fields
        )
    }
}
#endif
