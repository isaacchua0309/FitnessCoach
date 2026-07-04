//
//  FormaBuildConfiguration.swift
//  Fitness Coach
//
//  Forma — Build flavor detection for Settings and internal tooling.
//

import Foundation

enum FormaBuildConfiguration {
    static let internalBuildInfoPlistKey = "FORMA_INTERNAL_BUILD"

    /// Internal/TestFlight vs App Store archive detection (facade over FormaAbTest).
    static var isInternalBuildEnabled: Bool {
        FormaAbTest.Build.internalBuildEnabled
    }

    static func internalBuildFlag(from bundle: Bundle) -> Bool {
        _ = bundle
        return FormaAbTest.Build.internalBuildEnabled
    }

    /// `true` when developer-oriented Settings should be shown.
    static var isDebugOrInternalBuild: Bool {
        #if DEBUG
        return true
        #else
        return FormaAbTest.Build.internalBuildEnabled
        #endif
    }

    /// Whether developer-tool destinations are compiled into the binary.
    static var includesCompiledDeveloperTools: Bool {
        FormaAbTest.Build.includesDeveloperTools
    }
}
