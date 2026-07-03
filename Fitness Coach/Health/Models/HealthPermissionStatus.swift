//
//  HealthPermissionStatus.swift
//  Fitness Coach
//
//  Forma — Aggregated Health Intelligence permission state with per-signal detail.
//
//  Partial authorization is valid and expected: users may grant steps and workouts but
//  deny sleep or heart metrics. Sync and repository reads treat each signal independently
//  so available data is still cached and surfaced without requiring all-or-nothing access.
//

import Foundation

struct HealthPermissionStatus: Equatable, Sendable {
    let isHealthDataAvailable: Bool
    let signalAccess: [HealthSignalKind: HealthSignalAccess]
    let resolvedAt: Date

    func access(for signal: HealthSignalKind) -> HealthSignalAccess {
        signalAccess[signal] ?? .unavailable
    }

    var availableSignals: Set<HealthSignalKind> {
        Set(signalAccess.compactMap { signal, access in
            access == .available ? signal : nil
        })
    }

    var deniedSignals: Set<HealthSignalKind> {
        Set(signalAccess.compactMap { signal, access in
            access == .denied ? signal : nil
        })
    }

    /// Core training reads used by Today (workouts and/or steps).
    var hasTrainingReadAccess: Bool {
        access(for: .workout).isReadable || access(for: .stepCount).isReadable
    }

    var hasAnyAvailableReadAccess: Bool {
        !availableSignals.isEmpty
    }

    var allRequiredSignalsAvailable: Bool {
        HealthSignalKind.required.allSatisfy { access(for: $0).isReadable }
    }

    var anyRequiredSignalDenied: Bool {
        HealthSignalKind.required.contains { access(for: $0) == .denied }
    }

    static func unavailable(resolvedAt: Date = Date()) -> HealthPermissionStatus {
        let access = Dictionary(
            uniqueKeysWithValues: HealthSignalKind.allCases.map { ($0, HealthSignalAccess.unavailable) }
        )
        return HealthPermissionStatus(
            isHealthDataAvailable: false,
            signalAccess: access,
            resolvedAt: resolvedAt
        )
    }

    static func uniform(
        _ access: HealthSignalAccess,
        isHealthDataAvailable: Bool,
        signals: [HealthSignalKind] = HealthSignalKind.allCases,
        resolvedAt: Date = Date()
    ) -> HealthPermissionStatus {
        HealthPermissionStatus(
            isHealthDataAvailable: isHealthDataAvailable,
            signalAccess: Dictionary(uniqueKeysWithValues: signals.map { ($0, access) }),
            resolvedAt: resolvedAt
        )
    }
}
