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

enum AccountRemoteDataInspectionFailure: Equatable, Sendable {
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
        let recentDates = await MainActor.run {
            AccountSyncPuller.localDates(
                from: dailyRange.start,
                to: dailyRange.end,
                calendar: calendar
            )
        }

        var failures: [AccountRemoteDataInspectionFailure] = []
        var updatedAtCandidates: [Date?] = []

        var hasCloudProfile = false
        var hasRecentDailyLogs = false
        var hasRecentFoodEntries = false
        var hasRecentWaterEntries = false
        var hasWeightHistory = false
        var hasDailyReviews = false

        do {
            if let profile = try await cloudProfileStore.fetch(uid: normalizedUID) {
                hasCloudProfile = true
                updatedAtCandidates.append(profile.updatedAt)
            }
        } catch {
            failures.append(AccountRemoteDataInspectionSupport.classify(error))
        }

        do {
            let dailyLogs = try await remoteStore.fetchDailyLogs(
                uid: normalizedUID,
                from: dailyRange.start,
                to: dailyRange.end
            )
            let visibleLogs = dailyLogs.filter { AccountRemoteDataInspectionSupport.isVisible($0.deletedAt) }
            hasRecentDailyLogs = !visibleLogs.isEmpty
            updatedAtCandidates.append(contentsOf: visibleLogs.map(\.updatedAt))
        } catch {
            failures.append(AccountRemoteDataInspectionSupport.classify(error))
        }

        if !hasRecentFoodEntries {
            for localDate in recentDates {
                do {
                    let foodEntries = try await remoteStore.fetchFoodEntries(
                        uid: normalizedUID,
                        localDate: localDate
                    )
                    let visibleEntries = foodEntries.filter {
                        AccountRemoteDataInspectionSupport.isVisible($0.deletedAt)
                    }
                    if !visibleEntries.isEmpty {
                        hasRecentFoodEntries = true
                        updatedAtCandidates.append(contentsOf: visibleEntries.map(\.updatedAt))
                        break
                    }
                } catch {
                    failures.append(AccountRemoteDataInspectionSupport.classify(error))
                    break
                }
            }
        }

        if !hasRecentWaterEntries {
            for localDate in recentDates {
                do {
                    let waterEntries = try await remoteStore.fetchWaterEntries(
                        uid: normalizedUID,
                        localDate: localDate
                    )
                    let visibleEntries = waterEntries.filter {
                        AccountRemoteDataInspectionSupport.isVisible($0.deletedAt)
                    }
                    if !visibleEntries.isEmpty {
                        hasRecentWaterEntries = true
                        updatedAtCandidates.append(contentsOf: visibleEntries.map(\.updatedAt))
                        break
                    }
                } catch {
                    failures.append(AccountRemoteDataInspectionSupport.classify(error))
                    break
                }
            }
        }

        if !hasDailyReviews {
            for localDate in recentDates {
                do {
                    if let review = try await remoteStore.fetchDailyReview(
                        uid: normalizedUID,
                        localDate: localDate
                    ), AccountRemoteDataInspectionSupport.isVisible(review.deletedAt) {
                        hasDailyReviews = true
                        updatedAtCandidates.append(review.updatedAt)
                        break
                    }
                } catch {
                    failures.append(AccountRemoteDataInspectionSupport.classify(error))
                    break
                }
            }
        }

        do {
            let weightEntries = try await remoteStore.fetchWeightEntries(
                uid: normalizedUID,
                from: weightRange.start,
                to: weightRange.end
            )
            let visibleEntries = weightEntries.filter {
                AccountRemoteDataInspectionSupport.isVisible($0.deletedAt)
            }
            hasWeightHistory = !visibleEntries.isEmpty
            updatedAtCandidates.append(contentsOf: visibleEntries.map(\.updatedAt))
        } catch {
            failures.append(AccountRemoteDataInspectionSupport.classify(error))
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
