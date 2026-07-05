//
//  AppContainer+Construction.swift
//  Fitness Coach
//
//  Shared construction utilities for AppContainer.
//  Domain bundles live under App/Dependencies/.
//  See Docs/Architecture/DependencyInjectionMap.md
//

import Foundation

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
