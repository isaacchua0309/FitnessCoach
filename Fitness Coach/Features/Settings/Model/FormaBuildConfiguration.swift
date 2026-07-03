//
//  FormaBuildConfiguration.swift
//  Fitness Coach
//
//  Forma — Build flavor detection for Settings and internal tooling.
//

import Foundation

enum FormaBuildConfiguration {
    /// `true` for local debug and other internal builds; `false` for App Store / TestFlight release.
    static var isDebugOrInternalBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
