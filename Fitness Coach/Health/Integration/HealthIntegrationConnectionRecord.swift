//
//  HealthIntegrationConnectionRecord.swift
//  Fitness Coach
//
//  Forma — Persisted Apple Health connection-flow evidence (not permission truth).
//

import Foundation

struct HealthIntegrationConnectionRecord: Equatable, Sendable, Codable {
    var hasCompletedAppleHealthConnectionFlow: Bool
    var lastHealthPermissionRequestAt: Date?
    var lastSuccessfulHealthReadAt: Date?
    var lastHealthSyncAttemptAt: Date?

    static let empty = HealthIntegrationConnectionRecord(
        hasCompletedAppleHealthConnectionFlow: false,
        lastHealthPermissionRequestAt: nil,
        lastSuccessfulHealthReadAt: nil,
        lastHealthSyncAttemptAt: nil
    )

    func hasPriorConnectionEvidence(
        trainingIntegrationState: TrainingIntegrationState,
        permissionStatus: HealthPermissionStatus?
    ) -> Bool {
        hasCompletedAppleHealthConnectionFlow
            || lastSuccessfulHealthReadAt != nil
            || trainingIntegrationState.isConnected
            || permissionStatus?.hasAnyReadableSignal == true
    }
}

protocol HealthIntegrationConnectionStoring: Sendable {
    func load() -> HealthIntegrationConnectionRecord
    func save(_ record: HealthIntegrationConnectionRecord)
    func clear()
}

struct UserDefaultsHealthIntegrationConnectionStore: HealthIntegrationConnectionStoring {

    private enum Key {
        static let record = "forma.healthIntegration.connectionRecord"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> HealthIntegrationConnectionRecord {
        guard let data = userDefaults.data(forKey: Key.record),
              let decoded = try? JSONDecoder().decode(HealthIntegrationConnectionRecord.self, from: data) else {
            return .empty
        }
        return decoded
    }

    func save(_ record: HealthIntegrationConnectionRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        userDefaults.set(data, forKey: Key.record)
    }

    func clear() {
        userDefaults.removeObject(forKey: Key.record)
    }
}

struct LockedHealthIntegrationConnectionStore: HealthIntegrationConnectionStoring, @unchecked Sendable {

    private var record: HealthIntegrationConnectionRecord = .empty
    private let lock = NSLock()

    func load() -> HealthIntegrationConnectionRecord {
        lock.lock()
        defer { lock.unlock() }
        return record
    }

    func save(_ record: HealthIntegrationConnectionRecord) {
        lock.lock()
        self.record = record
        lock.unlock()
    }

    func clear() {
        lock.lock()
        record = .empty
        lock.unlock()
    }
}

enum HealthIntegrationConnectionRecorder {

    static func recordPermissionRequestStarted(
        store: any HealthIntegrationConnectionStoring,
        at date: Date = Date()
    ) {
        var record = store.load()
        record.lastHealthPermissionRequestAt = date
        store.save(record)
    }

    static func recordConnectionCompleted(
        store: any HealthIntegrationConnectionStoring,
        at date: Date = Date()
    ) {
        var record = store.load()
        record.hasCompletedAppleHealthConnectionFlow = true
        record.lastHealthPermissionRequestAt = record.lastHealthPermissionRequestAt ?? date
        store.save(record)
    }

    static func recordSyncAttempt(
        store: any HealthIntegrationConnectionStoring,
        at date: Date = Date()
    ) {
        var record = store.load()
        record.lastHealthSyncAttemptAt = date
        store.save(record)
    }

    static func recordSuccessfulRead(
        store: any HealthIntegrationConnectionStoring,
        at date: Date = Date()
    ) {
        var record = store.load()
        record.lastSuccessfulHealthReadAt = date
        if !record.hasCompletedAppleHealthConnectionFlow {
            record.hasCompletedAppleHealthConnectionFlow = true
        }
        store.save(record)
    }
}
