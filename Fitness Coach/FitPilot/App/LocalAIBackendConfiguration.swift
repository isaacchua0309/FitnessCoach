//
//  LocalAIBackendConfiguration.swift
//  Fitness Coach
//
//  Resolves the debug local AI gateway URL for simulator vs physical device.
//

import Foundation

enum LocalAIBackendConfiguration {

    static let defaultPort = 8787

    /// Priority: Xcode scheme env → `DeveloperLocal.plist` → simulator localhost.
    /// Physical devices return `nil` when unset so debug builds fall back to `MockLLMClient`.
    static func debugBackendURL() -> URL? {
        if let url = url(from: ProcessInfo.processInfo.environment["FITPILOT_AI_BACKEND_URL"]) {
            return url
        }
        if let url = url(from: bundledURLString) {
            return url
        }
        #if targetEnvironment(simulator)
        return URL(string: "http://127.0.0.1:\(defaultPort)")
        #else
        return nil
        #endif
    }

    private static var bundledURLString: String? {
        guard let path = Bundle.main.path(forResource: "DeveloperLocal", ofType: "plist"),
              let dictionary = NSDictionary(contentsOfFile: path),
              let value = dictionary["FITPILOT_AI_BACKEND_URL"] as? String,
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func url(from string: String?) -> URL? {
        guard let string, !string.isEmpty else { return nil }
        return URL(string: string)
    }
}
