//
//  AccountRealtimeChangeListener.swift
//  Fitness Coach
//
//  Forma — Narrow realtime change-hint abstraction for cross-device sync (Phase 5).
//
//  Listeners emit lightweight UID hints only. Merge and UI refresh happen in
//  CrossDeviceSyncCoordinator.handleRealtimeHint(uid:).
//

import Foundation

protocol AccountRealtimeChangeListening: AnyObject {
    func startListening(uid: String) async
    func stopListening(uid: String) async
    func stopAll() async
    var onRemoteChangeHint: ((String) -> Void)? { get set }
}

enum AccountRealtimeChangeListenerSupport {

    /// Collections observed for change hints (Option A — no food/water subcollection listeners).
    static let hintedCollectionSegments: [String] = [
        AccountDataCloudPaths.Segment.dailyLogs,
        AccountDataCloudPaths.Segment.weightEntries,
        AccountDataCloudPaths.Segment.dailyReviews
    ]

    static let profileDocumentSegment = AccountDataCloudPaths.Segment.profile

    static var isEnabled: Bool {
        AccountPersistenceFeatureFlags.syncEngineEnabled
            && AccountPersistenceFeatureFlags.realtimeCrossDeviceSyncEnabled
            && FormaAbTest.AccountPersistence.realtimeCrossDeviceSyncEnabled
    }

    static func normalizedUID(_ uid: String) -> String? {
        try? AccountSyncMutationValidation.normalizedOwnerUID(uid)
    }
}

/// Coalesces rapid Firestore snapshot callbacks before emitting a single hint.
final class AccountRealtimeChangeHintDebouncer: @unchecked Sendable {

    private let debounceInterval: Duration
    private let lock = NSLock()
    private var debounceTask: Task<Void, Never>?

    init(debounceInterval: Duration = CrossDeviceSyncPolicy.realtimeDebounceInterval()) {
        self.debounceInterval = debounceInterval
    }

    func schedule(uid: String, handler: @escaping @Sendable (String) -> Void) {
        lock.lock()
        debounceTask?.cancel()
        debounceTask = Task { [debounceInterval] in
            try? await Task.sleep(for: debounceInterval)
            guard !Task.isCancelled else { return }
            handler(uid)
        }
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        debounceTask?.cancel()
        debounceTask = nil
        lock.unlock()
    }
}

/// No-op listener used when realtime cross-device sync is disabled.
final class NoOpAccountRealtimeChangeListener: AccountRealtimeChangeListening, @unchecked Sendable {

    var onRemoteChangeHint: ((String) -> Void)?

    func startListening(uid: String) async {}
    func stopListening(uid: String) async {}
    func stopAll() async {}
}

enum AccountRealtimeChangeListenerLifecycle {

    /// Routes listener hints into the cross-device coordinator debounced pull path.
    @MainActor
    static func connect(
        listener: AccountRealtimeChangeListening,
        crossDeviceCoordinator: CrossDeviceSyncCoordinating
    ) {
        listener.onRemoteChangeHint = { uid in
            Task { @MainActor in
                _ = await crossDeviceCoordinator.handleRealtimeHint(uid: uid)
            }
        }
    }

    @MainActor
    static func startIfEnabled(
        listener: AccountRealtimeChangeListening,
        uid: String
    ) {
        guard AccountRealtimeChangeListenerSupport.isEnabled else { return }
        guard AccountRealtimeChangeListenerSupport.normalizedUID(uid) != nil else { return }
        Task {
            await listener.startListening(uid: uid)
        }
    }

    @MainActor
    static func stopOnAccountSwitch(listener: AccountRealtimeChangeListening) {
        Task {
            await listener.stopAll()
        }
    }
}
