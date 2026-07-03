//
//  HealthSignalAccess.swift
//  Fitness Coach
//
//  Forma — Per-signal HealthKit read access resolution.
//

import Foundation

enum HealthSignalAccess: String, Equatable, Sendable, Codable {
    /// HealthKit or the signal type is not supported on this device.
    case unavailable
    /// User has not been prompted for this signal yet.
    case notDetermined
    /// User denied read access for this signal.
    case denied
    /// Read access could not be classified (treated as not yet usable).
    case unknown
    /// Read access probe succeeded for this signal.
    case available

    var isReadable: Bool {
        self == .available
    }
}
