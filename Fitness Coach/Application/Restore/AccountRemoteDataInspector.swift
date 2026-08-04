//
//  AccountRemoteDataInspector.swift
//  Fitness Coach
//
//  Forma — Cloud account data presence probe for restore routing (Phase 4).
//
//  Read-only inspection over bounded Firestore ranges. Does not merge data locally.
//

import Foundation

struct AccountRemoteDataStatus: Equatable, Sendable {
    let uid: String
    let hasCloudProfile: Bool
    let hasRecentDailyLogs: Bool
    let hasRecentFoodEntries: Bool
    let hasRecentWaterEntries: Bool
    let hasWeightHistory: Bool
    let hasDailyReviews: Bool
    let hasAnyRestorableData: Bool
    let newestRemoteUpdatedAt: Date?
    let failure: AccountRemoteDataInspectionFailure?
}

enum AccountRemoteDataInspectionFailure: Error, Equatable, Sendable {
    case offline
    case permissionDenied
    case unauthenticated
    case unavailable
    case decodingFailed
    case unknown
}

protocol AccountRemoteDataInspecting {
    func inspectRemoteData(for uid: String, today: Date) async -> AccountRemoteDataStatus
}

enum AccountRemoteDataInspectionSupport {

    static func classify(_ error: Error) -> AccountRemoteDataInspectionFailure {
        if let storeError = error as? AccountDataRemoteStoreError {
            switch storeError {
            case .decodingFailed:
                return .decodingFailed
            case .userIdMismatch, .invalidDocumentPath, .encodingFailed:
                return .unknown
            }
        }

        if let nutritionError = error as? NutritionSyncError, case .notAuthenticated = nutritionError {
            return .unauthenticated
        }

        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case URLError.notConnectedToInternet.rawValue,
                 URLError.networkConnectionLost.rawValue,
                 URLError.timedOut.rawValue,
                 URLError.cannotFindHost.rawValue,
                 URLError.cannotConnectToHost.rawValue,
                 URLError.dataNotAllowed.rawValue:
                return .offline
            default:
                break
            }
        }

        if nsError.domain == firestoreErrorDomain {
            switch nsError.code {
            case 7:
                return .permissionDenied
            case 14:
                return .unavailable
            case 16:
                return .unauthenticated
            default:
                break
            }
        }

        if nsError.localizedDescription.localizedCaseInsensitiveContains("offline")
            || nsError.localizedDescription.localizedCaseInsensitiveContains("network") {
            return .offline
        }

        return .unknown
    }

    static func resolvedFailure(
        from failures: [AccountRemoteDataInspectionFailure],
        hasAnyRestorableData: Bool
    ) -> AccountRemoteDataInspectionFailure? {
        guard !hasAnyRestorableData else { return nil }
        guard let failure = failures.first else { return nil }
        return failures.reduce(failure) { current, candidate in
            failurePriority(candidate) > failurePriority(current) ? candidate : current
        }
    }

    static func isVisible(_ deletedAt: Date?) -> Bool {
        deletedAt == nil
    }

    static func newestUpdatedAt(_ dates: [Date?]) -> Date? {
        dates.compactMap { $0 }.max()
    }

    private static let firestoreErrorDomain = "FIRFirestoreErrorDomain"

    private static func failurePriority(_ failure: AccountRemoteDataInspectionFailure) -> Int {
        switch failure {
        case .unauthenticated:
            return 6
        case .permissionDenied:
            return 5
        case .offline:
            return 4
        case .decodingFailed:
            return 3
        case .unavailable:
            return 2
        case .unknown:
            return 1
        }
    }
}

struct AccountRemoteDataInspector: AccountRemoteDataInspecting {

    private let cloudProfileStore: CloudUserProfileStoring
    private let remoteStore: any AccountDataRemoteStore
    private let calendar: Calendar

    init(
        cloudProfileStore: CloudUserProfileStoring,
        remoteStore: any AccountDataRemoteStore,
        calendar: Calendar = AccountRemoteDataInspector.defaultCalendar
    ) {
        self.cloudProfileStore = cloudProfileStore
        self.remoteStore = remoteStore
        self.calendar = calendar
    }

    func inspectRemoteData(for uid: String, today: Date) async -> AccountRemoteDataStatus {
        let normalizedUID: String
        do {
            normalizedUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        } catch {
            return Self.emptyStatus(
                uid: uid.trimmingCharacters(in: .whitespacesAndNewlines),
                failure: .unknown
            )
        }

        let dailyRange = AccountRestorePolicy.dailyLogDateRange(
            for: .blockingInitial,
            referenceDate: today,
            calendar: calendar
        )
        let weightRange = AccountRestorePolicy.weightDateRange(
            for: .blockingInitial,
            referenceDate: today,
            calendar: calendar
        )

        // Presence probe only: three concurrent range/document reads.
        // Child collections are probed for at most one recent day when top-level
        // signals are empty — never walk the full lookback window.
        async let profileOutcome = fetchProfilePresence(uid: normalizedUID)
        async let dailyLogsOutcome = fetchDailyLogsPresence(
            uid: normalizedUID,
            from: dailyRange.start,
            to: dailyRange.end
        )
        async let weightOutcome = fetchWeightPresence(
            uid: normalizedUID,
            from: weightRange.start,
            to: weightRange.end
        )

        let profile = await profileOutcome
        let dailyLogs = await dailyLogsOutcome
        let weights = await weightOutcome

        var failures: [AccountRemoteDataInspectionFailure] = []
        var updatedAtCandidates: [Date?] = []

        var hasCloudProfile = false
        var hasRecentDailyLogs = false
        var hasRecentFoodEntries = false
        var hasRecentWaterEntries = false
        var hasWeightHistory = false
        var hasDailyReviews = false

        switch profile {
        case .success(let updatedAt):
            if let updatedAt {
                hasCloudProfile = true
                updatedAtCandidates.append(updatedAt)
            }
        case .failure(let failure):
            failures.append(failure)
        }

        var newestLogDate: String?
        switch dailyLogs {
        case .success(let result):
            hasRecentDailyLogs = result.hasLogs
            updatedAtCandidates.append(contentsOf: result.updatedAts)
            newestLogDate = result.newestLocalDate
        case .failure(let failure):
            failures.append(failure)
        }

        switch weights {
        case .success(let result):
            hasWeightHistory = result.hasEntries
            updatedAtCandidates.append(contentsOf: result.updatedAts)
        case .failure(let failure):
            failures.append(failure)
        }

        // Single-day child probe (newest log or today) — never walk the full lookback.
        let probeDate = newestLogDate
            ?? CloudAccountDataDateCodec.localDateString(from: today, calendar: calendar)
        let childPresence = await fetchChildPresence(uid: normalizedUID, localDate: probeDate)
        hasRecentFoodEntries = childPresence.hasFood
        hasRecentWaterEntries = childPresence.hasWater
        hasDailyReviews = childPresence.hasReview
        updatedAtCandidates.append(contentsOf: childPresence.updatedAts)
        if !hasCloudProfile && !hasRecentDailyLogs && !hasWeightHistory {
            failures.append(contentsOf: childPresence.failures)
        }

        let hasAnyRestorableData = hasCloudProfile
            || hasRecentDailyLogs
            || hasRecentFoodEntries
            || hasRecentWaterEntries
            || hasWeightHistory
            || hasDailyReviews

        return AccountRemoteDataStatus(
            uid: normalizedUID,
            hasCloudProfile: hasCloudProfile,
            hasRecentDailyLogs: hasRecentDailyLogs,
            hasRecentFoodEntries: hasRecentFoodEntries,
            hasRecentWaterEntries: hasRecentWaterEntries,
            hasWeightHistory: hasWeightHistory,
            hasDailyReviews: hasDailyReviews,
            hasAnyRestorableData: hasAnyRestorableData,
            newestRemoteUpdatedAt: AccountRemoteDataInspectionSupport.newestUpdatedAt(updatedAtCandidates),
            failure: AccountRemoteDataInspectionSupport.resolvedFailure(
                from: failures,
                hasAnyRestorableData: hasAnyRestorableData
            )
        )
    }

    private struct DailyLogsPresence: Sendable {
        var hasLogs = false
        var newestLocalDate: String?
        var updatedAts: [Date?] = []
    }

    private struct WeightPresence: Sendable {
        var hasEntries = false
        var updatedAts: [Date?] = []
    }

    private struct ChildPresence: Sendable {
        var hasFood = false
        var hasWater = false
        var hasReview = false
        var updatedAts: [Date?] = []
        var failures: [AccountRemoteDataInspectionFailure] = []
    }

    private func fetchProfilePresence(
        uid: String
    ) async -> Result<Date?, AccountRemoteDataInspectionFailure> {
        do {
            if let profile = try await cloudProfileStore.fetch(uid: uid) {
                return .success(profile.updatedAt)
            }
            let missing: Date? = nil
            return .success(missing)
        } catch {
            return .failure(AccountRemoteDataInspectionSupport.classify(error))
        }
    }

    private func fetchDailyLogsPresence(
        uid: String,
        from startDate: String,
        to endDate: String
    ) async -> Result<DailyLogsPresence, AccountRemoteDataInspectionFailure> {
        do {
            let dailyLogs = try await remoteStore.fetchDailyLogs(
                uid: uid,
                from: startDate,
                to: endDate
            )
            let visibleLogs = dailyLogs.filter { AccountRemoteDataInspectionSupport.isVisible($0.deletedAt) }
            let newest = visibleLogs.max(by: { $0.localDate < $1.localDate })
            return .success(
                DailyLogsPresence(
                    hasLogs: !visibleLogs.isEmpty,
                    newestLocalDate: newest?.localDate,
                    updatedAts: visibleLogs.map(\.updatedAt)
                )
            )
        } catch {
            return .failure(AccountRemoteDataInspectionSupport.classify(error))
        }
    }

    private func fetchWeightPresence(
        uid: String,
        from startDate: String,
        to endDate: String
    ) async -> Result<WeightPresence, AccountRemoteDataInspectionFailure> {
        do {
            let weightEntries = try await remoteStore.fetchWeightEntries(
                uid: uid,
                from: startDate,
                to: endDate
            )
            let visibleEntries = weightEntries.filter {
                AccountRemoteDataInspectionSupport.isVisible($0.deletedAt)
            }
            return .success(
                WeightPresence(
                    hasEntries: !visibleEntries.isEmpty,
                    updatedAts: visibleEntries.map(\.updatedAt)
                )
            )
        } catch {
            return .failure(AccountRemoteDataInspectionSupport.classify(error))
        }
    }

    private func fetchChildPresence(uid: String, localDate: String) async -> ChildPresence {
        async let foodOutcome = fetchFoodPresence(uid: uid, localDate: localDate)
        async let waterOutcome = fetchWaterPresence(uid: uid, localDate: localDate)
        async let reviewOutcome = fetchReviewPresence(uid: uid, localDate: localDate)

        let food = await foodOutcome
        let water = await waterOutcome
        let review = await reviewOutcome

        var presence = ChildPresence()
        switch food {
        case .success(let result):
            presence.hasFood = result.hasEntries
            presence.updatedAts.append(contentsOf: result.updatedAts)
        case .failure(let failure):
            presence.failures.append(failure)
        }
        switch water {
        case .success(let result):
            presence.hasWater = result.hasEntries
            presence.updatedAts.append(contentsOf: result.updatedAts)
        case .failure(let failure):
            presence.failures.append(failure)
        }
        switch review {
        case .success(let updatedAt):
            if let updatedAt {
                presence.hasReview = true
                presence.updatedAts.append(updatedAt)
            }
        case .failure(let failure):
            presence.failures.append(failure)
        }
        return presence
    }

    private struct EntriesPresence: Sendable {
        var hasEntries = false
        var updatedAts: [Date?] = []
    }

    private func fetchFoodPresence(
        uid: String,
        localDate: String
    ) async -> Result<EntriesPresence, AccountRemoteDataInspectionFailure> {
        do {
            let foodEntries = try await remoteStore.fetchFoodEntries(uid: uid, localDate: localDate)
            let visible = foodEntries.filter { AccountRemoteDataInspectionSupport.isVisible($0.deletedAt) }
            return .success(EntriesPresence(hasEntries: !visible.isEmpty, updatedAts: visible.map(\.updatedAt)))
        } catch {
            return .failure(AccountRemoteDataInspectionSupport.classify(error))
        }
    }

    private func fetchWaterPresence(
        uid: String,
        localDate: String
    ) async -> Result<EntriesPresence, AccountRemoteDataInspectionFailure> {
        do {
            let waterEntries = try await remoteStore.fetchWaterEntries(uid: uid, localDate: localDate)
            let visible = waterEntries.filter { AccountRemoteDataInspectionSupport.isVisible($0.deletedAt) }
            return .success(EntriesPresence(hasEntries: !visible.isEmpty, updatedAts: visible.map(\.updatedAt)))
        } catch {
            return .failure(AccountRemoteDataInspectionSupport.classify(error))
        }
    }

    private func fetchReviewPresence(
        uid: String,
        localDate: String
    ) async -> Result<Date?, AccountRemoteDataInspectionFailure> {
        do {
            if let review = try await remoteStore.fetchDailyReview(uid: uid, localDate: localDate),
               AccountRemoteDataInspectionSupport.isVisible(review.deletedAt) {
                return .success(review.updatedAt)
            }
            let missing: Date? = nil
            return .success(missing)
        } catch {
            return .failure(AccountRemoteDataInspectionSupport.classify(error))
        }
    }

    private static var defaultCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func emptyStatus(
        uid: String,
        failure: AccountRemoteDataInspectionFailure?
    ) -> AccountRemoteDataStatus {
        AccountRemoteDataStatus(
            uid: uid,
            hasCloudProfile: false,
            hasRecentDailyLogs: false,
            hasRecentFoodEntries: false,
            hasRecentWaterEntries: false,
            hasWeightHistory: false,
            hasDailyReviews: false,
            hasAnyRestorableData: false,
            newestRemoteUpdatedAt: nil,
            failure: failure
        )
    }
}
