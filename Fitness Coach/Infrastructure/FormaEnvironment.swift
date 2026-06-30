//
//  FormaEnvironment.swift
//  Fitness Coach
//
//  Process environment lookup with legacy FitPilot key fallback (Phase 6).
//

import Foundation

enum FormaEnvironment {

    /// Reads `primary` from the process environment, then optional `legacy` key.
    static func string(primary: String, legacy: String? = nil) -> String? {
        let env = ProcessInfo.processInfo.environment
        if let value = env[primary], !value.isEmpty { return value }
        if let legacy, let value = env[legacy], !value.isEmpty { return value }
        return nil
    }

    /// Returns whether a trace-style flag is enabled (`!= "0"`). Checks primary then legacy.
    static func isTracingEnabled(primary: String, legacy: String, defaultEnabled: Bool = true) -> Bool {
        if let value = string(primary: primary, legacy: legacy) {
            return value != "0"
        }
        return defaultEnabled
    }

    static func isMockLLMEnabled() -> Bool {
        string(primary: "FORMA_USE_MOCK_LLM", legacy: "FITPILOT_USE_MOCK_LLM") == "1"
    }

    static func aiBackendURLString() -> String? {
        string(primary: "FORMA_AI_BACKEND_URL", legacy: "FITPILOT_AI_BACKEND_URL")
    }
}
