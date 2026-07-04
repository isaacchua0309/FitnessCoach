//
//  AccountDataRemoteStore.swift
//  Fitness Coach
//
//  Forma — Remote store protocol for account-backed Firestore documents (Phase 2).
//
//  Injectable infrastructure only. Not wired into production log mutation flows.
//

import Foundation

enum AccountDataRemoteStoreError: Error, Equatable, Sendable {
    case userIdMismatch(expected: String, actual: String)
    case invalidDocumentPath
    case decodingFailed
    case encodingFailed
}

extension AccountDataRemoteStoreError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .userIdMismatch(let expected, let actual):
            return "Document userId \(actual) does not match session \(expected)."
        case .invalidDocumentPath:
            return "The Firestore document path is invalid."
        case .decodingFailed:
            return "Failed to decode account data cloud document."
        case .encodingFailed:
            return "Failed to encode account data cloud document."
        }
    }
}

protocol AccountDataRemoteStore: Sendable {
    func fetchDailyLog(uid: String, localDate: String) async throws -> CloudDailyLogDocument?
    func saveDailyLog(_ document: CloudDailyLogDocument, uid: String) async throws
    func fetchDailyLogs(uid: String, from startDate: String, to endDate: String) async throws -> [CloudDailyLogDocument]

    func fetchFoodEntries(uid: String, localDate: String) async throws -> [CloudFoodEntryDocument]
    func saveFoodEntry(_ document: CloudFoodEntryDocument, uid: String) async throws
    func deleteFoodEntry(uid: String, localDate: String, entryId: String) async throws

    func fetchWaterEntries(uid: String, localDate: String) async throws -> [CloudWaterEntryDocument]
    func saveWaterEntry(_ document: CloudWaterEntryDocument, uid: String) async throws
    func deleteWaterEntry(uid: String, localDate: String, entryId: String) async throws

    func fetchWeightEntries(uid: String, from startDate: String?, to endDate: String?) async throws -> [CloudWeightEntryDocument]
    func saveWeightEntry(_ document: CloudWeightEntryDocument, uid: String) async throws
    func deleteWeightEntry(uid: String, entryId: String) async throws

    func fetchDailyReview(uid: String, localDate: String) async throws -> CloudDailyReviewDocument?
    func saveDailyReview(_ document: CloudDailyReviewDocument, uid: String) async throws
    func deleteDailyReview(uid: String, localDate: String) async throws

    func fetchSyncMetadata(uid: String) async throws -> CloudSyncMetadataDocument?
    func saveSyncMetadata(_ document: CloudSyncMetadataDocument, uid: String) async throws
}

enum AccountDataRemoteStoreSupport {

    static func normalizedUID(_ uid: String) throws -> String {
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AccountDataRemoteStoreError.invalidDocumentPath }
        return trimmed
    }

    static func validateLocalDate(_ localDate: String) throws -> String {
        let trimmed = localDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard CloudAccountDataDateCodec.date(
            fromLocalDateString: trimmed,
            calendar: Calendar(identifier: .gregorian)
        ) != nil else {
            throw AccountDataRemoteStoreError.invalidDocumentPath
        }
        return trimmed
    }

    static func validateUserIdMatch(documentUserId: String, uid: String) throws {
        let normalizedUID = try normalizedUID(uid)
        let normalizedDocumentUserId = documentUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedDocumentUserId == normalizedUID else {
            throw AccountDataRemoteStoreError.userIdMismatch(
                expected: normalizedUID,
                actual: normalizedDocumentUserId
            )
        }
    }

    static func validateWrite<T: CloudAccountDataDocument>(_ document: T, uid: String) throws {
        try validateUserIdMatch(documentUserId: document.userId, uid: uid)
        guard document.schemaVersion > 0 else {
            throw AccountDataRemoteStoreError.invalidDocumentPath
        }
    }

    static func validateDateRange(from startDate: String, to endDate: String) throws -> (String, String) {
        let start = try validateLocalDate(startDate)
        let end = try validateLocalDate(endDate)
        guard start <= end else {
            throw AccountDataRemoteStoreError.invalidDocumentPath
        }
        return (start, end)
    }
}

// MARK: - In-memory test double

actor InMemoryAccountDataRemoteStore: AccountDataRemoteStore {

    private var dailyLogs: [String: [String: CloudDailyLogDocument]] = [:]
    private var foodEntries: [String: [String: [String: CloudFoodEntryDocument]]] = [:]
    private var waterEntries: [String: [String: [String: CloudWaterEntryDocument]]] = [:]
    private var weightEntries: [String: [String: CloudWeightEntryDocument]] = [:]
    private var dailyReviews: [String: [String: CloudDailyReviewDocument]] = [:]
    private var syncMetadata: [String: CloudSyncMetadataDocument] = [:]

    func fetchDailyLog(uid: String, localDate: String) async throws -> CloudDailyLogDocument? {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(localDate)
        return dailyLogs[normalizedUID]?[normalizedDate]
    }

    func saveDailyLog(_ document: CloudDailyLogDocument, uid: String) async throws {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        try AccountDataRemoteStoreSupport.validateWrite(document, uid: normalizedUID)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(document.localDate)
        dailyLogs[normalizedUID, default: [:]][normalizedDate] = document
    }

    func fetchDailyLogs(uid: String, from startDate: String, to endDate: String) async throws -> [CloudDailyLogDocument] {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let range = try AccountDataRemoteStoreSupport.validateDateRange(from: startDate, to: endDate)
        return (dailyLogs[normalizedUID] ?? [:])
            .filter { range.0 <= $0.key && $0.key <= range.1 }
            .map(\.value)
            .sorted { $0.localDate < $1.localDate }
    }

    func fetchFoodEntries(uid: String, localDate: String) async throws -> [CloudFoodEntryDocument] {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(localDate)
        return Array((foodEntries[normalizedUID]?[normalizedDate] ?? [:]).values)
    }

    func saveFoodEntry(_ document: CloudFoodEntryDocument, uid: String) async throws {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        try AccountDataRemoteStoreSupport.validateWrite(document, uid: normalizedUID)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(document.localDate)
        foodEntries[normalizedUID, default: [:]][normalizedDate, default: [:]][document.id] = document
    }

    func deleteFoodEntry(uid: String, localDate: String, entryId: String) async throws {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(localDate)
        foodEntries[normalizedUID]?[normalizedDate]?.removeValue(forKey: entryId)
    }

    func fetchWaterEntries(uid: String, localDate: String) async throws -> [CloudWaterEntryDocument] {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(localDate)
        return Array((waterEntries[normalizedUID]?[normalizedDate] ?? [:]).values)
    }

    func saveWaterEntry(_ document: CloudWaterEntryDocument, uid: String) async throws {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        try AccountDataRemoteStoreSupport.validateWrite(document, uid: normalizedUID)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(document.localDate)
        waterEntries[normalizedUID, default: [:]][normalizedDate, default: [:]][document.id] = document
    }

    func deleteWaterEntry(uid: String, localDate: String, entryId: String) async throws {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(localDate)
        waterEntries[normalizedUID]?[normalizedDate]?.removeValue(forKey: entryId)
    }

    func fetchWeightEntries(
        uid: String,
        from startDate: String?,
        to endDate: String?
    ) async throws -> [CloudWeightEntryDocument] {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let start = try startDate.map(AccountDataRemoteStoreSupport.validateLocalDate)
        let end = try endDate.map(AccountDataRemoteStoreSupport.validateLocalDate)
        if let start, let end {
            _ = try AccountDataRemoteStoreSupport.validateDateRange(from: start, to: end)
        }

        return (weightEntries[normalizedUID] ?? [:])
            .values
            .filter { document in
                if let start, document.localDate < start { return false }
                if let end, document.localDate > end { return false }
                return true
            }
            .sorted { $0.localDate < $1.localDate }
    }

    func saveWeightEntry(_ document: CloudWeightEntryDocument, uid: String) async throws {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        try AccountDataRemoteStoreSupport.validateWrite(document, uid: normalizedUID)
        weightEntries[normalizedUID, default: [:]][document.id] = document
    }

    func deleteWeightEntry(uid: String, entryId: String) async throws {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        weightEntries[normalizedUID]?.removeValue(forKey: entryId)
    }

    func fetchDailyReview(uid: String, localDate: String) async throws -> CloudDailyReviewDocument? {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(localDate)
        return dailyReviews[normalizedUID]?[normalizedDate]
    }

    func saveDailyReview(_ document: CloudDailyReviewDocument, uid: String) async throws {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        try AccountDataRemoteStoreSupport.validateWrite(document, uid: normalizedUID)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(document.localDate)
        dailyReviews[normalizedUID, default: [:]][normalizedDate] = document
    }

    func deleteDailyReview(uid: String, localDate: String) async throws {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(localDate)
        dailyReviews[normalizedUID]?.removeValue(forKey: normalizedDate)
    }

    func fetchSyncMetadata(uid: String) async throws -> CloudSyncMetadataDocument? {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        return syncMetadata[normalizedUID]
    }

    func saveSyncMetadata(_ document: CloudSyncMetadataDocument, uid: String) async throws {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        try AccountDataRemoteStoreSupport.validateWrite(document, uid: normalizedUID)
        syncMetadata[normalizedUID] = document
    }
}
