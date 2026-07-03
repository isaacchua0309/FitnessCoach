//
//  HealthSyncError.swift
//  Fitness Coach
//
//  Forma — Errors surfaced by HealthSyncService.
//

import Foundation

enum HealthSyncError: Error, Equatable, Sendable {
    case alreadySyncing
    case permissionDenied
    case healthDataUnavailable
    case signalUnavailable(HealthSignalKind)
    case signalFailed(HealthSignalKind, reason: String)
    case cancelled

    var localizedDescription: String {
        switch self {
        case .alreadySyncing:
            return "A health sync is already in progress."
        case .permissionDenied:
            return "Apple Health read permission was denied."
        case .healthDataUnavailable:
            return "Apple Health is unavailable on this device."
        case .signalUnavailable(let signal):
            return "Health signal unavailable: \(signal.rawValue)."
        case .signalFailed(let signal, let reason):
            return "Failed to sync \(signal.rawValue): \(reason)"
        case .cancelled:
            return "Health sync was cancelled."
        }
    }
}
