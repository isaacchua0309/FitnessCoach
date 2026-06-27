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
    }

    // MARK: - Public API

    var isHealthDataAvailable: Bool {
        authorizer.isHealthDataAvailable
    }

    func authorizationStatus() -> HealthTrainingAuthorizationStatus {
        if let stub = debugStubAuthorizationStatus() {
            return stub
        }
        return authorizer.workoutReadAuthorizationStatus()
    }

    func refreshState() async -> TrainingIntegrationState {
        authorizationStatus().integrationState
    }

    func requestConnection() async -> TrainingIntegrationState {
        guard dataSource == .appleHealth else {
            return .unavailable
        }
        guard authorizer.isHealthDataAvailable else {
            return .unavailable
        }

        let result = await authorizer.requestReadAuthorization()
        return result.integrationState
    }

    // MARK: - Preview / test stubs

    func setStubConnected(_ connected: Bool) {
        userDefaults.set(connected, forKey: StorageKey.stubConnected)
        if connected {
            userDefaults.set(false, forKey: StorageKey.stubDenied)
        }
    }

    func setStubDenied(_ denied: Bool) {
        userDefaults.set(denied, forKey: StorageKey.stubDenied)
        if denied {
            userDefaults.set(false, forKey: StorageKey.stubConnected)
        }
    }

    func resetStubFlags() {
        userDefaults.removeObject(forKey: StorageKey.stubConnected)
        userDefaults.removeObject(forKey: StorageKey.stubDenied)
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
