//
//  FormaEnvironment.swift
//  Fitness Coach
//
//  Process environment lookup with legacy FitPilot key fallback (Phase 6).
//

import Foundation

enum FormaEnvironment {

    /// Reads `primary` from the process environment, then optional `legacy` key,
    /// then `Info.plist` values substituted at build time (Release / TestFlight).
    static func string(
        primary: String,
        legacy: String? = nil,
        environment: [String: String]? = nil
    ) -> String? {
        if let value = processEnvironmentValue(primary: primary, legacy: legacy, environment: environment) {
            return value
        }
        return bundledInfoPlistValue(primary: primary, legacy: legacy)
    }

    private static func processEnvironmentValue(
        primary: String,
        legacy: String?,
        environment: [String: String]?
    ) -> String? {
        let env = environment ?? ProcessInfo.processInfo.environment
        if let value = env[primary], !value.isEmpty { return value }
        if let legacy, let value = env[legacy], !value.isEmpty { return value }
        return nil
    }

    private static func bundledInfoPlistValue(primary: String, legacy: String?) -> String? {
        for key in [primary, legacy].compactMap({ $0 }) {
            guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
                  isUsableBundledValue(value) else {
                continue
            }
            return value
        }
        return nil
    }

    private static func isUsableBundledValue(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Unsubstituted Xcode build setting, e.g. "$(FORMA_AI_BACKEND_URL)".
        if trimmed.hasPrefix("$("), trimmed.hasSuffix(")") { return false }
        return true
    }

    /// Returns whether a trace-style flag is enabled (`!= "0"`). Checks primary then legacy.
    static func isTracingEnabled(primary: String, legacy: String, defaultEnabled: Bool = true) -> Bool {
        if let value = string(primary: primary, legacy: legacy) {
            return value != "0"
        }
        return defaultEnabled
    }

    static func aiBackendURLString(environment: [String: String]? = nil) -> String? {
        string(
            primary: "FORMA_AI_BACKEND_URL",
            legacy: "FITPILOT_AI_BACKEND_URL",
            environment: environment
        )
    }

    #if DEBUG
    enum AIBackendURLDetection: Equatable {
        case notDetected
        case detected(source: AIBackendURLSource)
    }

    enum AIBackendURLSource: String {
        case processEnvironment
        case infoPlist
    }

    /// Whether `FORMA_AI_BACKEND_URL` resolved without logging the URL value.
    static func aiBackendURLDetection(environment: [String: String]? = nil) -> AIBackendURLDetection {
        if processEnvironmentValue(
            primary: "FORMA_AI_BACKEND_URL",
            legacy: "FITPILOT_AI_BACKEND_URL",
            environment: environment
        ) != nil {
            return .detected(source: .processEnvironment)
        }
        if bundledInfoPlistValue(
            primary: "FORMA_AI_BACKEND_URL",
            legacy: "FITPILOT_AI_BACKEND_URL"
        ) != nil {
            return .detected(source: .infoPlist)
        }
        return .notDetected
    }
    #endif
}
