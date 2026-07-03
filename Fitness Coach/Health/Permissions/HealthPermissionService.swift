//
//  HealthPermissionService.swift
//  Fitness Coach
//
//  Forma — Permission orchestration for Health Intelligence reads.
//

import Foundation

protocol HealthPermissionServing: Sendable {
    var isHealthDataAvailable: Bool { get }
    func currentStatus(
        includingFutureTypes: Bool
    ) async -> HealthPermissionStatus
    func requestPermissions(
        includingFutureTypes: Bool
    ) async throws -> HealthPermissionStatus
}

extension HealthPermissionServing {
    func currentStatus() async -> HealthPermissionStatus {
        await currentStatus(includingFutureTypes: false)
    }

    func requestPermissions() async throws -> HealthPermissionStatus {
        try await requestPermissions(includingFutureTypes: false)
    }
}

struct HealthPermissionService: HealthPermissionServing {

    private let healthKitManager: any HealthKitManaging

    init(healthKitManager: any HealthKitManaging = HealthKitManager()) {
        self.healthKitManager = healthKitManager
    }

    var isHealthDataAvailable: Bool {
        healthKitManager.isHealthDataAvailable
    }

    func currentStatus(
        includingFutureTypes: Bool = false
    ) async -> HealthPermissionStatus {
        guard healthKitManager.isHealthDataAvailable else {
            HealthPermissionLogger.warn("currentStatus: Health data unavailable on device")
            return .unavailable()
        }

        let status = await healthKitManager.getAuthorizationStatus(
            includingFutureTypes: includingFutureTypes
        )
        HealthPermissionLogger.logResolvedStatus(status, context: "currentStatus")
        return status
    }

    func requestPermissions(
        includingFutureTypes: Bool = false
    ) async throws -> HealthPermissionStatus {
        guard healthKitManager.isHealthDataAvailable else {
            HealthPermissionLogger.warn("requestPermissions: Health data unavailable on device")
            return .unavailable()
        }

        do {
            let previous = await healthKitManager.getAuthorizationStatus(
                includingFutureTypes: includingFutureTypes
            )
            let status = try await healthKitManager.requestAuthorization(
                includingFutureTypes: includingFutureTypes
            )
            if previous != status {
                HealthPermissionLogger.permissionStateChanged(
                    context: "requestPermissions",
                    previousAvailableCount: previous.availableSignals.count,
                    previousDeniedCount: previous.deniedSignals.count,
                    current: status
                )
                HealthIntelligencePipelineAnalytics.logPermissionResolved(status)
            }
            HealthPermissionLogger.logResolvedStatus(status, context: "requestPermissions")
            return status
        } catch HealthKitManagerError.unavailable {
            return .unavailable()
        } catch HealthKitManagerError.authorizationDenied {
            return await currentStatus(includingFutureTypes: includingFutureTypes)
        } catch {
            HealthPermissionLogger.authorizationFailure(
                context: "requestPermissions",
                underlying: error
            )
            return await currentStatus(includingFutureTypes: includingFutureTypes)
        }
    }
}
