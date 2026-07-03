//
//  HealthDataAvailability.swift
//  Fitness Coach
//
//  Forma — Repository-facing health data availability snapshot.
//

import Foundation

struct HealthDataAvailability: Equatable, Sendable {
    let isHealthDataAvailable: Bool
    let permissionStatus: HealthPermissionStatus
    let cachedDayCount: Int

    var hasAnyReadableSignal: Bool {
        permissionStatus.hasAnyAvailableReadAccess
    }

    var hasTrainingReadAccess: Bool {
        permissionStatus.hasTrainingReadAccess
    }
}

struct HealthRefreshResult: Equatable, Sendable {
    let daysRefreshed: Int
    let refreshedAt: Date
}
