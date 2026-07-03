//
//  FormaAppMetadata.swift
//  Fitness Coach
//
//  Forma — Bundle metadata for Settings About rows.
//

import Foundation

enum FormaAppMetadata {

    static func marketingVersion(bundle: Bundle = .main) -> String {
        stringValue(for: "CFBundleShortVersionString", bundle: bundle) ?? "—"
    }

    static func buildNumber(bundle: Bundle = .main) -> String? {
        stringValue(for: "CFBundleVersion", bundle: bundle)
    }

    static func versionDisplayString(bundle: Bundle = .main) -> String {
        let version = marketingVersion(bundle: bundle)
        guard let build = buildNumber(bundle: bundle), !build.isEmpty else {
            return version
        }
        return "\(version) (\(build))"
    }

    private static func stringValue(for key: String, bundle: Bundle) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
