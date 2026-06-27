//
//  HealthTrainingService.swift
//  Fitness Coach
//
//  Forma — Apple Health training integration (read-only authorization).
//

import Foundation

@MainActor
final class HealthTrainingService: TrainingIntegrationProviding, @unchecked Sendable {

    private enum StorageKey {
        static let stubConnected = "forma.trainingIntegration.stubConnected"
        static let stubDenied = "forma.trainingIntegration.stubDenied"
    }

    private let authorizer: HealthKitTrainingAuthorizing
    private let userDefaults: UserDefaults

    nonisolated var dataSource: TrainingDataSource {
        TrainingDataSource.preferredOnDevice
    }

    init(
        authorizer: HealthKitTrainingAuthorizing? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.authorizer = authorizer ?? Self.makeDefaultAuthorizer()
        self.userDefaults = userDefaults
        HealthTrainingDebugLogger.event(
            "HealthTrainingService initialized",
            fields: [
                "dataSource": dataSource.rawValue,
                "healthDataAvailable": String(self.authorizer.isHealthDataAvailable),
                "authorizer": String(describing: type(of: self.authorizer))
            ]
        )
    }

    // MARK: - Public API

    var isHealthDataAvailable: Bool {
        authorizer.isHealthDataAvailable
    }

    func authorizationStatus() -> HealthTrainingAuthorizationStatus {
        if let stub = debugStubAuthorizationStatus() {
            HealthTrainingDebugLogger.logAuthorizationStatus(
                stub,
                context: "authorizationStatus",
                fields: ["source": "debugStub"]
            )
            return stub
        }
        return authorizer.workoutReadAuthorizationStatus()
    }

    private func resolvedAuthorizationStatus() async -> HealthTrainingAuthorizationStatus {
        if let stub = debugStubAuthorizationStatus() {
            HealthTrainingDebugLogger.logAuthorizationStatus(
                stub,
                context: "resolveWorkoutReadAccess",
                fields: ["source": "debugStub"]
            )
            return stub
        }
        let status = await authorizer.resolveWorkoutReadAccess()
        HealthTrainingDebugLogger.logAuthorizationStatus(status, context: "resolveWorkoutReadAccess")
        return status
    }

    func refreshState() async -> TrainingIntegrationState {
        let status = await resolvedAuthorizationStatus()
        let state = status.integrationState
        HealthTrainingDebugLogger.logIntegrationTransition(
            from: nil,
            to: state,
            action: "refreshState",
            fields: ["authorizationStatus": status.debugLabel]
        )
        return state
    }

    func requestConnection() async -> TrainingIntegrationState {
        HealthTrainingDebugLogger.event("requestConnection started")

        guard dataSource == .appleHealth else {
            HealthTrainingDebugLogger.warn(
                "requestConnection aborted: data source is not Apple Health",
                fields: ["dataSource": dataSource.rawValue]
            )
            return .unavailable
        }
        guard authorizer.isHealthDataAvailable else {
            HealthTrainingDebugLogger.warn("requestConnection aborted: Health data not available on device")
            return .unavailable
        }

        let before = await resolvedAuthorizationStatus()
        HealthTrainingDebugLogger.logAuthorizationStatus(
            before,
            context: "requestConnection.before"
        )

        let result = await authorizer.requestReadAuthorization()
        let state = result.integrationState

        HealthTrainingDebugLogger.logAuthorizationStatus(
            result,
            context: "requestConnection.after"
        )
        HealthTrainingDebugLogger.logIntegrationTransition(
            from: before.integrationState,
            to: state,
            action: "requestConnection",
            fields: ["authorizationStatus": result.debugLabel]
        )

        if state == .denied {
            HealthTrainingDebugLogger.warn(
                "Connect finished with access denied — user declined read access in the Health permission sheet"
            )
        }

        return state
    }

    // MARK: - Preview / test stubs

    func setStubConnected(_ connected: Bool) {
        userDefaults.set(connected, forKey: StorageKey.stubConnected)
        if connected {
            userDefaults.set(false, forKey: StorageKey.stubDenied)
        }
        HealthTrainingDebugLogger.event("Debug stub connected flag set", fields: ["connected": String(connected)])
    }

    func setStubDenied(_ denied: Bool) {
        userDefaults.set(denied, forKey: StorageKey.stubDenied)
        if denied {
            userDefaults.set(false, forKey: StorageKey.stubConnected)
        }
        HealthTrainingDebugLogger.event("Debug stub denied flag set", fields: ["denied": String(denied)])
    }

    func resetStubFlags() {
        userDefaults.removeObject(forKey: StorageKey.stubConnected)
        userDefaults.removeObject(forKey: StorageKey.stubDenied)
        HealthTrainingDebugLogger.event("Debug stub flags reset")
    }

    // MARK: - Private

    private func debugStubAuthorizationStatus() -> HealthTrainingAuthorizationStatus? {
        if userDefaults.bool(forKey: StorageKey.stubDenied) {
            return .sharingDenied
        }
        if userDefaults.bool(forKey: StorageKey.stubConnected) {
            return .sharingAuthorized
        }
        return nil
    }

    nonisolated private static func makeDefaultAuthorizer() -> HealthKitTrainingAuthorizing {
        #if canImport(HealthKit) && os(iOS)
        return SystemHealthKitTrainingAuthorization()
        #else
        return UnavailableHealthKitTrainingAuthorization()
        #endif
    }
}
