//
//  HealthPermissionService.swift
//  Fitness Coach
//
//  Forma — Permission orchestration for Health Intelligence reads.
//

import Foundation

enum HealthPermissionStatus: Equatable, Sendable {
    case unavailable
    case notDetermined
    case denied
    case authorized
}

protocol HealthPermissionServing: Sendable {
    var isHealthDataAvailable: Bool { get }
    func currentStatus() async -> HealthPermissionStatus
    func requestPermissions() async throws -> HealthPermissionStatus
}

struct HealthPermissionService: HealthPermissionServing {

    private let healthKitManager: any HealthKitManaging

    init(healthKitManager: any HealthKitManaging = HealthKitManager()) {
        self.healthKitManager = healthKitManager
    }

    var isHealthDataAvailable: Bool {
        healthKitManager.isHealthDataAvailable
    }

    func currentStatus() async -> HealthPermissionStatus {
        // TODO: Resolve fine-grained read access via probe queries per data category.
        guard healthKitManager.isHealthDataAvailable else {
            return .unavailable
        }
        return .notDetermined
    }

    func requestPermissions() async throws -> HealthPermissionStatus {
        guard healthKitManager.isHealthDataAvailable else {
            return .unavailable
        }

        do {
            try await healthKitManager.requestAuthorization()
        } catch HealthKitManagerError.unavailable {
            return .unavailable
        } catch {
            return .denied
        }

        return await currentStatus()
    }
}
