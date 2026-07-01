//
//  AIBackendConfiguration.swift
//  Fitness Coach
//
//  Resolves the hosted Firebase aiGateway URL for all build configurations.
//

import Foundation
import OSLog

enum AIBackendConfiguration {

    static let environmentVariableName = "FORMA_AI_BACKEND_URL"
    static let legacyEnvironmentVariableName = "FITPILOT_AI_BACKEND_URL"

    /// Production Firebase aiGateway base URL (no `/v1/ai/...` suffix).
    static let productionGatewayURLString =
        "https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway"

    private static let logger = Logger(subsystem: "Forma", category: "AIBackend")

    /// Priority: process environment → `Info.plist` (`FORMA_AI_BACKEND_URL` build setting).
    /// Localhost hosts are always rejected.
    static func backendURL(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        guard let raw = FormaEnvironment.aiBackendURLString(environment: environment)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty else {
            logger.error("AI gateway URL missing from environment and Info.plist.")
            return nil
        }

        guard let url = URL(string: raw), let host = url.host?.lowercased() else {
            logger.error("AI gateway URL is invalid: \(raw, privacy: .public)")
            return nil
        }

        guard isLocalhostHost(host) == false else {
            logger.error(
                "AI gateway URL rejected (localhost not allowed): \(raw, privacy: .public)"
            )
            return nil
        }

        guard url.scheme == "https" || url.scheme == "http" else {
            logger.error(
                "AI gateway URL rejected (unsupported scheme): \(raw, privacy: .public)"
            )
            return nil
        }

        return url
    }

    static func unavailableReason(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UnavailableLLMReason {
        guard let raw = FormaEnvironment.aiBackendURLString(environment: environment)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty,
            let url = URL(string: raw) else {
            return .releaseBackendNotConfigured
        }

        if isLocalhostURL(url) {
            return .releaseBackendURLRejectedLocalhost
        }

        return .releaseBackendNotConfigured
    }

    static func isLocalhostURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return isLocalhostHost(host)
    }

    static func isLocalhostHost(_ host: String) -> Bool {
        switch host {
        case "localhost", "127.0.0.1", "::1", "0.0.0.0":
            return true
        default:
            return false
        }
    }
}
