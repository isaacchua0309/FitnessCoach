//
//  TrainingIntegrationState.swift
//  Fitness Coach
//
//  Forma — Apple Health training integration lifecycle (Stage 2).
//

import Foundation

/// Lifecycle for connecting Apple Health as the official training data source.
enum TrainingIntegrationState: Equatable, Sendable {
    case unavailable
    case notConnected
    case requestingPermission
    case connected
    case denied
    case failed(message: String)
}

/// Which backend supplies official training insights.
enum TrainingDataSource: String, Equatable, Sendable, Codable {
    case appleHealth
    case unavailable
}

extension TrainingIntegrationState {

    /// Insights dashboard can load workout summaries from the official source.
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    /// User should see the connection gate instead of an empty training dashboard.
    var showsConnectionGate: Bool {
        switch self {
        case .notConnected, .denied, .failed:
            return true
        case .unavailable, .requestingPermission, .connected:
            return false
        }
    }

    /// Connection flow is in progress; disable duplicate connect taps.
    var isRequestingPermission: Bool {
        if case .requestingPermission = self { return true }
        return false
    }
}

extension TrainingDataSource {

    /// Official product source is Apple Health on supported platforms.
    nonisolated static var preferredOnDevice: TrainingDataSource {
        #if os(iOS)
        return .appleHealth
        #else
        return .unavailable
        #endif
    }
}
