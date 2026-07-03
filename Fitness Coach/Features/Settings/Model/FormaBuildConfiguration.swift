//
//  FormaBuildConfiguration.swift
//  Fitness Coach
//
//  Forma — Build flavor detection for Settings and internal tooling.
//

import Foundation

enum FormaBuildConfiguration {
    static let internalBuildInfoPlistKey = "FORMA_INTERNAL_BUILD"

    /// Reads the internal-build flag baked into Info.plist at archive time.
    /// Set `FORMA_INTERNAL_BUILD = 1` for internal TestFlight archives; keep `0` for App Store release.
    static var isInternalBuildEnabled: Bool {
        internalBuildFlag(from: .main)
    }

    static func internalBuildFlag(from bundle: Bundle) -> Bool {
        guard let value = bundle.object(forInfoDictionaryKey: internalBuildInfoPlistKey) as? String else {
            return false
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return false }
        return trimmed == "1"
    }

    /// `true` for DEBUG builds and internal/TestFlight archives with `FORMA_INTERNAL_BUILD = 1`.
    static var isDebugOrInternalBuild: Bool {
        #if DEBUG
        return true
        #else
        return isInternalBuildEnabled
        #endif
    }

    /// Whether developer-tool destinations are compiled into the binary.
    static var includesCompiledDeveloperTools: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
