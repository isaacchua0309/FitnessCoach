//
//  FormaAnalyticsConfiguration.swift
//  Fitness Coach
//
//  Forma — Explicit analytics sink routing configuration.
//
//  Registry: Docs/Architecture/AnalyticsReadinessChecklist.md
//

import Foundation

/// Controls which analytics sinks `AnalyticsLoggerFactory` may wire.
///
/// Release ships with `releaseDefault` — production sink disabled, NoOp in Release builds.
/// No Firebase Analytics or network sinks are integrated.
struct FormaAnalyticsConfiguration: Equatable, Sendable {

    /// When `true`, a future production adapter may be composed behind each protocol.
    /// Remains `false` until product approves a backend and adapters ship.
    let isProductionSinkEnabled: Bool

    /// DEBUG builds: OSLog sinks only; production disabled.
    static let debug = FormaAnalyticsConfiguration(isProductionSinkEnabled: false)

    /// Release default: NoOp sinks; production explicitly disabled.
    static let releaseDefault = FormaAnalyticsConfiguration(isProductionSinkEnabled: false)

    /// Unit tests: production disabled unless a test injects an override logger.
    static let testing = FormaAnalyticsConfiguration(isProductionSinkEnabled: false)

    /// Active configuration for app wiring.
    static var current: FormaAnalyticsConfiguration {
        #if DEBUG
        return .debug
        #else
        return .releaseDefault
        #endif
    }
}
