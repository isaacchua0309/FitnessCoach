//
//  AuthUIDCache.swift
//  Fitness Coach
//
//  Forma — Thread-safe Firebase UID cache for health storage scoping.
//

import Foundation

final class AuthUIDCache: HealthCacheUserProviding, @unchecked Sendable {

    private var uid: String?
    private let lock = NSLock()

    func update(uid: String?) {
        let trimmed = uid?.trimmingCharacters(in: .whitespacesAndNewlines)
        lock.lock()
        self.uid = trimmed?.isEmpty == false ? trimmed : nil
        lock.unlock()
    }

    /// Returns `true` when the cached UID changed.
    @discardableResult
    func updateIfChanged(uid: String?) -> Bool {
        let trimmed = uid?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed?.isEmpty == false ? trimmed : nil
        lock.lock()
        let changed = normalized != self.uid
        self.uid = normalized
        lock.unlock()
        return changed
    }

    func currentUserID() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return uid
    }
}
