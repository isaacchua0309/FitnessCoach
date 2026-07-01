//
//  ReleaseAIBackendConfiguration.swift
//  Fitness Coach
//
//  Resolves the production AI gateway URL for Release builds.
//  Release must never fall back to localhost — see Docs/ReleaseAI.md.
//

import Foundation
import OSLog

enum ReleaseAIBackendConfiguration {

    static let environmentVariableName = "FORMA_AI_BACKEND_URL"
    static let legacyEnvironmentVariableName = "FITPILOT_AI_BACKEND_URL"

    private static let logger = Logger(subsystem: "Forma", category: "ReleaseAI")

    /// Returns a backend URL only when `FORMA_AI_BACKEND_URL` is set to a non-local host.
    static func releaseBackendURL(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        guard let raw = FormaEnvironment.aiBackendURLString()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty else {
            return nil
        }

        guard let url = URL(string: raw), let host = url.host?.lowercased() else {
            logger.error("Release AI backend URL is invalid: \(raw, privacy: .public)")
            return nil
        }

        guard isLocalhostHost(host) == false else {
            logger.error(
                "Release AI backend URL rejected (localhost not allowed): \(raw, privacy: .public)"
            )
            return nil
        }

        guard url.scheme == "https" || url.scheme == "http" else {
            logger.error(
                "Release AI backend URL rejected (unsupported scheme): \(raw, privacy: .public)"
            )
            return nil
        }

        return url
    }

    static func unavailableReason(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UnavailableLLMReason {
        guard let raw = FormaEnvironment.aiBackendURLString()?
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
