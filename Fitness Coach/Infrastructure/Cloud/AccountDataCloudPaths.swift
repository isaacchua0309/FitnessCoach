//
//  AccountDataCloudPaths.swift
//  Fitness Coach
//
//  Forma — Canonical Firestore paths for account-backed local data (Phase 2).
//

import Foundation

/// Firestore collection segments and full path helpers under `users/{uid}/`.
enum AccountDataCloudPaths {

    enum Segment {
        static let users = "users"
        static let profile = "profile"
        static let syncMetadata = "syncMetadata"
        static let dailyLogs = "dailyLogs"
        static let foodEntries = "foodEntries"
        static let waterEntries = "waterEntries"
        static let weightEntries = "weightEntries"
        static let dailyReviews = "dailyReviews"
        static let currentDocumentID = "current"
    }

    static func userRoot(uid: String) -> String {
        "\(Segment.users)/\(uid)"
    }

    static func profileDocument(uid: String) -> String {
        "\(userRoot(uid: uid))/\(Segment.profile)/\(Segment.currentDocumentID)"
    }

    static func dailyLogsCollection(uid: String) -> String {
        "\(userRoot(uid: uid))/\(Segment.dailyLogs)"
    }

    static func dailyLogDocument(uid: String, localDate: String) -> String {
        "\(dailyLogsCollection(uid: uid))/\(localDate)"
    }

    static func foodEntriesCollection(uid: String, localDate: String) -> String {
        "\(dailyLogDocument(uid: uid, localDate: localDate))/\(Segment.foodEntries)"
    }

    static func foodEntryDocument(uid: String, localDate: String, entryId: String) -> String {
        "\(foodEntriesCollection(uid: uid, localDate: localDate))/\(entryId)"
    }

    static func waterEntriesCollection(uid: String, localDate: String) -> String {
        "\(dailyLogDocument(uid: uid, localDate: localDate))/\(Segment.waterEntries)"
    }

    static func waterEntryDocument(uid: String, localDate: String, entryId: String) -> String {
        "\(waterEntriesCollection(uid: uid, localDate: localDate))/\(entryId)"
    }

    static func weightEntriesCollection(uid: String) -> String {
        "\(userRoot(uid: uid))/\(Segment.weightEntries)"
    }

    static func weightEntryDocument(uid: String, entryId: String) -> String {
        "\(weightEntriesCollection(uid: uid))/\(entryId)"
    }

    static func dailyReviewsCollection(uid: String) -> String {
        "\(userRoot(uid: uid))/\(Segment.dailyReviews)"
    }

    static func dailyReviewDocument(uid: String, localDate: String) -> String {
        "\(dailyReviewsCollection(uid: uid))/\(localDate)"
    }

    static func syncMetadataDocument(uid: String) -> String {
        "\(userRoot(uid: uid))/\(Segment.syncMetadata)/\(Segment.currentDocumentID)"
    }
}
