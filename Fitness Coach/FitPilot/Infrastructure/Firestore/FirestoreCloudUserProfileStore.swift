//
//  FirestoreCloudUserProfileStore.swift
//  Fitness Coach
//
//  FitPilot — Firestore-backed profile snapshot store.
//

import FirebaseFirestore
import Foundation

final class FirestoreCloudUserProfileStore: CloudUserProfileStoring, @unchecked Sendable {

    private lazy var firestore: Firestore = Firestore.firestore()

    func fetch(uid: String) async throws -> CloudUserProfileDocument? {
        ProfileBootstrapDebugLogger.event(
            "Fetching cloud profile",
            fields: ["uid": uid, "path": documentPath(uid: uid)]
        )

        let snapshot = try await documentReference(uid: uid).getDocument()
        guard snapshot.exists else {
            ProfileBootstrapDebugLogger.event("Cloud profile missing", fields: ["uid": uid])
            return nil
        }

        let document = try snapshot.data(as: CloudUserProfileDocument.self)
        ProfileBootstrapDebugLogger.event(
            "Cloud profile fetched",
            fields: [
                "uid": uid,
                "updatedAt": ISO8601DateFormatter().string(from: document.updatedAt)
            ]
        )
        return document
    }

    func save(profile: UserProfile, uid: String) async throws {
        let now = Date()
        let ref = documentReference(uid: uid)

        // Preserve onboardingCompletedAt on updates, but do not fail first-time
        // saves when the existence check cannot reach Firestore.
        var onboardingCompletedAt = profile.createdAt
        if let snapshot = try? await ref.getDocument(),
           snapshot.exists,
           let existing = try? snapshot.data(as: CloudUserProfileDocument.self) {
            onboardingCompletedAt = existing.onboardingCompletedAt
        }

        let document = CloudUserProfileDocument(
            profile: profile,
            onboardingCompletedAt: onboardingCompletedAt,
            updatedAt: now
        )

        ProfileBootstrapDebugLogger.event(
            "Saving cloud profile",
            fields: ["uid": uid, "path": documentPath(uid: uid)]
        )

        try ref.setData(from: document, merge: true)

        ProfileBootstrapDebugLogger.event("Cloud profile saved", fields: ["uid": uid])
    }

    private func documentReference(uid: String) -> DocumentReference {
        firestore
            .collection("users")
            .document(uid)
            .collection("profile")
            .document(CloudUserProfileDocument.currentDocumentID)
    }

    private func documentPath(uid: String) -> String {
        "users/\(uid)/profile/\(CloudUserProfileDocument.currentDocumentID)"
    }
}
