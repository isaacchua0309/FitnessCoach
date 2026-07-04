//
//  NutritionRemoteSyncCollections.swift
//  Fitness Coach
//
//  Forma — Firestore collection and document path constants for nutrition sync (Phase 2).
//

import Foundation

/// Firestore paths under `users/{uid}/` for nutrition account persistence.
enum NutritionRemoteSyncCollection {

    static let usersRoot = "users"
    static let syncMetadata = "syncMetadata"
    static let dailyLogs = "dailyLogs"
    static let foodEntries = "foodEntries"
    static let waterEntries = "waterEntries"
    static let weightEntries = "weightEntries"
    static let dailyReviews = "dailyReviews"

    /// Document id for singleton sync metadata (`syncMetadata/current`).
    static let currentDocumentID = "current"

    /// Cloud document schema version for nutrition payloads.
    static let schemaVersion = 1

    /// Client source marker written on nutrition cloud documents.
    static let source = "ios_forma"
}

enum NutritionRemoteSyncPaths {

    static func userDocument(uid: String) -> String {
        "\(NutritionRemoteSyncCollection.usersRoot)/\(uid)"
    }

    static func syncMetadataDocument(uid: String) -> String {
        "\(userDocument(uid: uid))/\(NutritionRemoteSyncCollection.syncMetadata)/\(NutritionRemoteSyncCollection.currentDocumentID)"
    }

    static func dailyLogDocument(uid: String, dayId: String) -> String {
        "\(userDocument(uid: uid))/\(NutritionRemoteSyncCollection.dailyLogs)/\(dayId)"
    }

    static func foodEntryDocument(uid: String, dayId: String, entryId: String) -> String {
        "\(dailyLogDocument(uid: uid, dayId: dayId))/\(NutritionRemoteSyncCollection.foodEntries)/\(entryId)"
    }

    static func waterEntryDocument(uid: String, dayId: String, entryId: String) -> String {
        "\(dailyLogDocument(uid: uid, dayId: dayId))/\(NutritionRemoteSyncCollection.waterEntries)/\(entryId)"
    }

    static func weightEntryDocument(uid: String, entryId: String) -> String {
        "\(userDocument(uid: uid))/\(NutritionRemoteSyncCollection.weightEntries)/\(entryId)"
    }

    static func dailyReviewDocument(uid: String, dayId: String) -> String {
        "\(userDocument(uid: uid))/\(NutritionRemoteSyncCollection.dailyReviews)/\(dayId)"
    }
}
