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

    // MARK: - Phase 5 incremental fetch (updatedAt cursors)

    func fetchDailyLogsUpdatedSince(
        uid: String,
        since: Date?,
        limit: Int
    ) async throws -> [CloudDailyLogDocument]

    func fetchFoodEntriesUpdatedSince(
        uid: String,
        since: Date?,
        from startDate: String,
        to endDate: String,
        limit: Int
    ) async throws -> [CloudFoodEntryDocument]

    func fetchWaterEntriesUpdatedSince(
        uid: String,
        since: Date?,
        from startDate: String,
        to endDate: String,
        limit: Int
    ) async throws -> [CloudWaterEntryDocument]

    func fetchWeightEntriesUpdatedSince(
        uid: String,
        since: Date?,
        limit: Int
    ) async throws -> [CloudWeightEntryDocument]

    func fetchDailyReviewsUpdatedSince(
        uid: String,
        since: Date?,
        limit: Int
    ) async throws -> [CloudDailyReviewDocument]

    /// Returns the cloud profile when `updatedAt` is newer than `since` (path-scoped to `uid`).
    func fetchCloudProfileUpdatedSince(uid: String, since: Date?) async throws -> CloudUserProfileDocument?
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

    static func localDates(
        from startDate: String,
        to endDate: String,
        calendar: Calendar = incrementalFetchCalendar
    ) -> [String] {
        guard let start = CloudAccountDataDateCodec.date(fromLocalDateString: startDate, calendar: calendar),
              let end = CloudAccountDataDateCodec.date(fromLocalDateString: endDate, calendar: calendar) else {
            return []
        }
        var dates: [String] = []
        var cursor = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while cursor <= endDay {
            dates.append(CloudAccountDataDateCodec.localDateString(from: cursor, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return dates
    }

    private static var incrementalFetchCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

// MARK: - Incremental fetch helpers

enum AccountDataRemoteStoreIncrementalSupport {

    static let defaultFetchLimit = 200
    static let maximumFetchLimit = 500

    static func clampLimit(_ limit: Int) -> Int {
        min(max(limit, 1), maximumFetchLimit)
    }

    /// Documents exactly at `since` were included in the prior pull.
    static func matchesUpdatedSince(_ updatedAt: Date, since: Date?) -> Bool {
        guard let since else { return true }
        return updatedAt > since
    }

    static func filterDocuments<T: CloudAccountDataDocument>(
        _ documents: [T],
        sessionUID: String,
        since: Date?
    ) -> [T] {
        documents.filter { document in
            guard document.userId.trimmingCharacters(in: .whitespacesAndNewlines) == sessionUID else {
                return false
            }
            return matchesUpdatedSince(document.updatedAt, since: since)
        }
    }

    static func sortByUpdatedAtAsc<T>(_ documents: [T], updatedAt: (T) -> Date) -> [T] {
        documents.sorted { updatedAt($0) < updatedAt($1) }
    }

    static func sortAndLimit<T>(
        _ documents: [T],
        limit: Int,
        updatedAt: (T) -> Date
    ) -> [T] {
        let sorted = sortByUpdatedAtAsc(documents, updatedAt: updatedAt)
        return Array(sorted.prefix(clampLimit(limit)))
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
    private var cloudProfiles: [String: CloudUserProfileDocument] = [:]

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

    // MARK: - Phase 5 incremental fetch

    func fetchDailyLogsUpdatedSince(
        uid: String,
        since: Date?,
        limit: Int
    ) async throws -> [CloudDailyLogDocument] {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let documents = (dailyLogs[normalizedUID] ?? [:]).values
        let filtered = AccountDataRemoteStoreIncrementalSupport.filterDocuments(
            Array(documents),
            sessionUID: normalizedUID,
            since: since
        )
        return AccountDataRemoteStoreIncrementalSupport.sortAndLimit(
            filtered,
            limit: limit,
            updatedAt: \.updatedAt
        )
    }

    func fetchFoodEntriesUpdatedSince(
        uid: String,
        since: Date?,
        from startDate: String,
        to endDate: String,
        limit: Int
    ) async throws -> [CloudFoodEntryDocument] {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let range = try AccountDataRemoteStoreSupport.validateDateRange(from: startDate, to: endDate)
        let localDates = AccountDataRemoteStoreSupport.localDates(from: range.0, to: range.1)
        var collected: [CloudFoodEntryDocument] = []
        for localDate in localDates {
            let dayEntries = Array((foodEntries[normalizedUID]?[localDate] ?? [:]).values)
            collected.append(
                contentsOf: AccountDataRemoteStoreIncrementalSupport.filterDocuments(
                    dayEntries,
                    sessionUID: normalizedUID,
                    since: since
                )
            )
        }
        return AccountDataRemoteStoreIncrementalSupport.sortAndLimit(
            collected,
            limit: limit,
            updatedAt: \.updatedAt
        )
    }

    func fetchWaterEntriesUpdatedSince(
        uid: String,
        since: Date?,
        from startDate: String,
        to endDate: String,
        limit: Int
    ) async throws -> [CloudWaterEntryDocument] {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let range = try AccountDataRemoteStoreSupport.validateDateRange(from: startDate, to: endDate)
        let localDates = AccountDataRemoteStoreSupport.localDates(from: range.0, to: range.1)
        var collected: [CloudWaterEntryDocument] = []
        for localDate in localDates {
            let dayEntries = Array((waterEntries[normalizedUID]?[localDate] ?? [:]).values)
            collected.append(
                contentsOf: AccountDataRemoteStoreIncrementalSupport.filterDocuments(
                    dayEntries,
                    sessionUID: normalizedUID,
                    since: since
                )
            )
        }
        return AccountDataRemoteStoreIncrementalSupport.sortAndLimit(
            collected,
            limit: limit,
            updatedAt: \.updatedAt
        )
    }

    func fetchWeightEntriesUpdatedSince(
        uid: String,
        since: Date?,
        limit: Int
    ) async throws -> [CloudWeightEntryDocument] {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let documents = Array((weightEntries[normalizedUID] ?? [:]).values)
        let filtered = AccountDataRemoteStoreIncrementalSupport.filterDocuments(
            documents,
            sessionUID: normalizedUID,
            since: since
        )
        return AccountDataRemoteStoreIncrementalSupport.sortAndLimit(
            filtered,
            limit: limit,
            updatedAt: \.updatedAt
        )
    }

    func fetchDailyReviewsUpdatedSince(
        uid: String,
        since: Date?,
        limit: Int
    ) async throws -> [CloudDailyReviewDocument] {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let documents = Array((dailyReviews[normalizedUID] ?? [:]).values)
        let filtered = AccountDataRemoteStoreIncrementalSupport.filterDocuments(
            documents,
            sessionUID: normalizedUID,
            since: since
        )
        return AccountDataRemoteStoreIncrementalSupport.sortAndLimit(
            filtered,
            limit: limit,
            updatedAt: \.updatedAt
        )
    }

    func fetchCloudProfileUpdatedSince(uid: String, since: Date?) async throws -> CloudUserProfileDocument? {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        guard let document = cloudProfiles[normalizedUID] else { return nil }
        guard AccountDataRemoteStoreIncrementalSupport.matchesUpdatedSince(document.updatedAt, since: since) else {
            return nil
        }
        return document
    }

    /// Seeds cloud profile snapshots for in-memory incremental fetch tests.
    func seedCloudProfile(_ document: CloudUserProfileDocument, uid: String) async throws {
        let normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        cloudProfiles[normalizedUID] = document
    }
}
