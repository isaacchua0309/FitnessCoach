//
//  FirestoreAccountRealtimeChangeListener.swift
//  Fitness Coach
//
//  Forma — Firestore snapshot listeners that emit cross-device change hints (Phase 5).
//
//  Option A: daily log collection changes hint food/water pulls for recent dates.
//  No food/water subcollection listeners, HealthKit listeners, coach listeners,
//  or raw meal image listeners in Phase 5.
//

import FirebaseFirestore
import Foundation

final class FirestoreAccountRealtimeChangeListener: AccountRealtimeChangeListening, @unchecked Sendable {

    var onRemoteChangeHint: ((String) -> Void)?

    private let firestoreProvider: () -> Firestore
    private let debouncer: AccountRealtimeChangeHintDebouncer
    private let lock = NSLock()
    private var sessions: [String: ListenerSession] = [:]

    init(
        firestore: @autoclosure @escaping () -> Firestore = Firestore.firestore(),
        debouncer: AccountRealtimeChangeHintDebouncer = AccountRealtimeChangeHintDebouncer()
    ) {
        self.firestoreProvider = firestore
        self.debouncer = debouncer
    }

    func startListening(uid: String) async {
        guard AccountRealtimeChangeListenerSupport.isEnabled else { return }
        guard let normalizedUID = AccountRealtimeChangeListenerSupport.normalizedUID(uid) else { return }

        lock.lock()
        if sessions[normalizedUID] != nil {
            lock.unlock()
            return
        }
        lock.unlock()

        await stopAll()

        var session = ListenerSession(uid: normalizedUID)
        let firestore = firestoreProvider()

        attachCollectionListener(
            uid: normalizedUID,
            collectionName: AccountDataCloudPaths.Segment.dailyLogs,
            collection: FirestoreNutritionSyncSupport.userCollection(
                firestore,
                uid: normalizedUID,
                name: AccountDataCloudPaths.Segment.dailyLogs
            ),
            session: &session
        )
        attachCollectionListener(
            uid: normalizedUID,
            collectionName: AccountDataCloudPaths.Segment.weightEntries,
            collection: FirestoreNutritionSyncSupport.userCollection(
                firestore,
                uid: normalizedUID,
                name: AccountDataCloudPaths.Segment.weightEntries
            ),
            session: &session
        )
        attachCollectionListener(
            uid: normalizedUID,
            collectionName: AccountDataCloudPaths.Segment.dailyReviews,
            collection: FirestoreNutritionSyncSupport.userCollection(
                firestore,
                uid: normalizedUID,
                name: AccountDataCloudPaths.Segment.dailyReviews
            ),
            session: &session
        )
        attachProfileListener(
            uid: normalizedUID,
            document: profileDocumentReference(firestore: firestore, uid: normalizedUID),
            session: &session
        )

        lock.lock()
        sessions[normalizedUID] = session
        lock.unlock()

        CrossDeviceSyncLogger.listenerStarted(uid: normalizedUID, listenerCount: session.registrations.count)
    }

    func stopListening(uid: String) async {
        guard let normalizedUID = AccountRealtimeChangeListenerSupport.normalizedUID(uid) else { return }
        let session = removeSession(for: normalizedUID)
        session?.registrations.forEach { $0.remove() }
        if session != nil {
            cancelDebounceIfNoSessions()
            CrossDeviceSyncLogger.listenerStopped(uid: normalizedUID, reason: "stopListening")
        }
    }

    func stopAll() async {
        let activeSessions = drainSessions()
        activeSessions.forEach { session in
            session.registrations.forEach { $0.remove() }
            CrossDeviceSyncLogger.listenerStopped(uid: session.uid, reason: "stopAll")
        }
        debouncer.cancel()
    }

    // MARK: - Listener attachment

    private func attachCollectionListener(
        uid: String,
        collectionName: String,
        collection: CollectionReference,
        session: inout ListenerSession
    ) {
        var hasSkippedInitialSnapshot = false
        let registration = collection.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            guard error == nil, let snapshot else { return }
            guard self.shouldEmitHint(
                snapshot: snapshot,
                hasSkippedInitialSnapshot: &hasSkippedInitialSnapshot
            ) else {
                return
            }
            self.scheduleHint(for: uid, source: collectionName)
        }
        session.registrations.append(registration)
    }

    private func attachProfileListener(
        uid: String,
        document: DocumentReference,
        session: inout ListenerSession
    ) {
        var hasSkippedInitialSnapshot = false
        let registration = document.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            guard error == nil, let snapshot else { return }
            guard self.shouldEmitHint(
                snapshot: snapshot,
                hasSkippedInitialSnapshot: &hasSkippedInitialSnapshot
            ) else {
                return
            }
            self.scheduleHint(for: uid, source: AccountDataCloudPaths.Segment.profile)
        }
        session.registrations.append(registration)
    }

    private func shouldEmitHint(
        snapshot: DocumentSnapshot,
        hasSkippedInitialSnapshot: inout Bool
    ) -> Bool {
        guard snapshot.metadata.hasPendingWrites == false else { return false }
        if !hasSkippedInitialSnapshot {
            hasSkippedInitialSnapshot = true
            return false
        }
        return true
    }

    private func shouldEmitHint(
        snapshot: QuerySnapshot,
        hasSkippedInitialSnapshot: inout Bool
    ) -> Bool {
        guard snapshot.metadata.hasPendingWrites == false else { return false }
        if !hasSkippedInitialSnapshot {
            hasSkippedInitialSnapshot = true
            return false
        }
        guard !snapshot.documentChanges.isEmpty else { return false }
        return true
    }

    private func scheduleHint(for uid: String, source: String) {
        debouncer.schedule(uid: uid) { [weak self] hintedUID in
            CrossDeviceSyncLogger.changeHintEmitted(uid: hintedUID, source: source)
            self?.onRemoteChangeHint?(hintedUID)
        }
    }

    // MARK: - Session bookkeeping

    private struct ListenerSession {
        let uid: String
        var registrations: [ListenerRegistration] = []
    }

    private func profileDocumentReference(firestore: Firestore, uid: String) -> DocumentReference {
        FirestoreNutritionSyncSupport.usersDocument(firestore, uid: uid)
            .collection(AccountDataCloudPaths.Segment.profile)
            .document(AccountDataCloudPaths.Segment.currentDocumentID)
    }

    private func removeSession(for uid: String) -> ListenerSession? {
        lock.lock()
        defer { lock.unlock() }
        return sessions.removeValue(forKey: uid)
    }

    private func drainSessions() -> [ListenerSession] {
        lock.lock()
        defer { lock.unlock() }
        let drained = Array(sessions.values)
        sessions.removeAll()
        return drained
    }

    private func cancelDebounceIfNoSessions() {
        lock.lock()
        let isEmpty = sessions.isEmpty
        lock.unlock()
        if isEmpty {
            debouncer.cancel()
        }
    }
}
