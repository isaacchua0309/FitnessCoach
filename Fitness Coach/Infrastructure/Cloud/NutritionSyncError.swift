//
//  NutritionSyncError.swift
//  Fitness Coach
//
//  Forma — Errors for nutrition Firestore remote clients (Phase 2).
//

import Foundation

enum NutritionSyncError: Error, Equatable, Sendable {
    case notAuthenticated
    case invalidUID
    case invalidDocument(String)
    case ownerMismatch(expectedUID: String, documentUID: String)
    case fetchFailed(collection: String, reason: String)
    case writeFailed(collection: String, reason: String)
    case batchWriteFailed(collection: String, reason: String)
    case encodingFailed
}

extension NutritionSyncError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "A signed-in Firebase user is required for nutrition cloud access."
        case .invalidUID:
            return "A valid Firebase UID is required for nutrition cloud access."
        case .invalidDocument(let reason):
            return "Invalid nutrition cloud document: \(reason)"
        case .ownerMismatch(let expectedUID, let documentUID):
            return "Nutrition document userId \(documentUID) does not match session \(expectedUID)."
        case .fetchFailed(let collection, let reason):
            return "Failed to fetch \(collection): \(reason)"
        case .writeFailed(let collection, let reason):
            return "Failed to write \(collection): \(reason)"
        case .batchWriteFailed(let collection, let reason):
            return "Failed batch write to \(collection): \(reason)"
        case .encodingFailed:
            return "Failed to encode nutrition cloud document."
        }
    }
}
