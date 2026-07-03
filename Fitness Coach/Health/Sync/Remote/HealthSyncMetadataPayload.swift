//
//  HealthSyncMetadataPayload.swift
//  Fitness Coach
//
//  Forma — Client sync metadata for remote Health Summary Sync.
//
//  Privacy boundary: sync timestamps, schema versions, bucketed permission summary,
//  and opaque error codes only. No raw HealthKit authorization payloads or user health
//  values.
//
//  Firestore: `/users/{uid}/healthSyncMetadata/current`
//

import Foundation

enum HealthSyncMetadataConnectionLevel: String, Equatable, Sendable, Codable, CaseIterable {
    case disconnected
    case partial
    case connected
    case unavailableOnDevice
}

struct HealthSyncPermissionSummary: Equatable, Sendable, Codable {
    let isHealthDataAvailable: Bool
    let connectionLevel: String
    let availableSignals: [String]
    let deniedSignals: [String]
    let cachedDayCount: Int
    let resolvedAt: String
}

struct HealthSyncMetadataPayload: Equatable, Sendable, Codable {
    let id: String
    let userId: String
    let localDate: String
    let timezone: String
    let generatedAt: String
    let source: HealthSummarySyncSource
    let confidence: HealthSyncConfidence
    let missingSignals: [String]
    let schemaVersion: Int

    let lastSuccessfulSyncAt: String?
    let clientSchemaVersion: Int
    let appVersion: String?
    let healthPermissionSummary: HealthSyncPermissionSummary
    let syncWindowDays: Int
    let lastSyncPhase: String?
    let lastSyncErrorCode: String?

    var firestorePath: String {
        HealthSummarySyncFirestorePath.metadata(userId: userId)
    }
}

extension HealthSyncMetadataPayload {

    /// Maps local sync state and permission availability into remote metadata.
    static func make(
        from syncState: HealthSyncState,
        permissionStatus: HealthPermissionStatus,
        cachedDayCount: Int,
        context: HealthSummarySyncMappingContext,
        syncWindowDays: Int = HealthCachePolicy.retentionDays,
        appVersion: String? = nil,
        isHealthDataAvailable: Bool? = nil
    ) -> HealthSyncMetadataPayload {
        let calendar = context.calendar
        let today = calendar.startOfDay(for: context.generatedAt)
        let localDate = HealthSummarySyncFormatting.localDateString(from: today, calendar: calendar)
        let healthAvailable = isHealthDataAvailable ?? permissionStatus.isHealthDataAvailable

        return HealthSyncMetadataPayload(
            id: HealthSummarySyncDocumentID.metadataDocumentID,
            userId: context.userId,
            localDate: localDate,
            timezone: context.timezoneIdentifier,
            generatedAt: HealthSummarySyncFormatting.iso8601UTCString(from: context.generatedAt),
            source: context.source,
            confidence: .unknown,
            missingSignals: [],
            schemaVersion: HealthSummarySyncSchemaVersion.current,
            lastSuccessfulSyncAt: syncState.lastSuccessfulSyncAt.map {
                HealthSummarySyncFormatting.iso8601UTCString(from: $0)
            },
            clientSchemaVersion: HealthSummarySyncSchemaVersion.clientMapperVersion,
            appVersion: appVersion,
            healthPermissionSummary: HealthSyncPermissionSummary(
                permissionStatus: permissionStatus,
                cachedDayCount: cachedDayCount,
                isHealthDataAvailable: healthAvailable
            ),
            syncWindowDays: syncWindowDays,
            lastSyncPhase: syncState.phase.rawValue,
            lastSyncErrorCode: opaqueErrorCode(from: syncState.lastError)
        )
    }

    /// Convenience overload using repository-facing availability snapshot.
    static func make(
        from syncState: HealthSyncState,
        availability: HealthDataAvailability,
        context: HealthSummarySyncMappingContext,
        syncWindowDays: Int = HealthCachePolicy.retentionDays,
        appVersion: String? = nil
    ) -> HealthSyncMetadataPayload {
        make(
            from: syncState,
            permissionStatus: availability.permissionStatus,
            cachedDayCount: availability.cachedDayCount,
            context: context,
            syncWindowDays: syncWindowDays,
            appVersion: appVersion,
            isHealthDataAvailable: availability.isHealthDataAvailable
        )
    }
}

extension HealthSyncPermissionSummary {

    init(
        permissionStatus: HealthPermissionStatus,
        cachedDayCount: Int,
        isHealthDataAvailable: Bool
    ) {
        self.isHealthDataAvailable = isHealthDataAvailable
        connectionLevel = Self.connectionLevel(
            permissionStatus: permissionStatus,
            isHealthDataAvailable: isHealthDataAvailable
        ).rawValue
        availableSignals = permissionStatus.availableSignals.map(\.rawValue).sorted()
        deniedSignals = permissionStatus.deniedSignals.map(\.rawValue).sorted()
        self.cachedDayCount = cachedDayCount
        resolvedAt = HealthSummarySyncFormatting.iso8601UTCString(from: permissionStatus.resolvedAt)
    }

    private static func connectionLevel(
        permissionStatus: HealthPermissionStatus,
        isHealthDataAvailable: Bool
    ) -> HealthSyncMetadataConnectionLevel {
        if !isHealthDataAvailable {
            return .unavailableOnDevice
        }

        if !permissionStatus.hasAnyAvailableReadAccess {
            return .disconnected
        }

        if permissionStatus.allRequiredSignalsAvailable {
            return .connected
        }

        return .partial
    }
}

extension HealthSyncMetadataPayload {

    fileprivate static func opaqueErrorCode(from error: HealthSyncError?) -> String? {
        guard let error else { return nil }
        switch error {
        case .alreadySyncing:
            return "already_syncing"
        case .permissionDenied:
            return "permission_denied"
        case .healthDataUnavailable:
            return "health_data_unavailable"
        case .signalUnavailable(let signal):
            return "signal_unavailable_\(signal.rawValue)"
        case .signalFailed(let signal, _):
            return "signal_failed_\(signal.rawValue)"
        case .cancelled:
            return "cancelled"
        }
    }
}
