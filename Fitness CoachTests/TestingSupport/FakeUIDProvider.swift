//
//  FakeUIDProvider.swift
//  Fitness CoachTests
//
//  Mutable session UID for account sync, restore, and ownership tests.
//

import Foundation
@testable import Fitness_Coach

final class FakeUIDProvider: @unchecked Sendable {

    private let lock = NSLock()
    private var uid: String?

    init(uid: String? = "test-user-a") {
        self.uid = uid
    }

    static func userA() -> FakeUIDProvider { FakeUIDProvider(uid: "test-user-a") }
    static func userB() -> FakeUIDProvider { FakeUIDProvider(uid: "test-user-b") }
    static func signedOut() -> FakeUIDProvider { FakeUIDProvider(uid: nil) }

    var currentUID: String? {
        lock.lock()
        defer { lock.unlock() }
        return uid
    }

    func setUID(_ value: String?) {
        lock.lock()
        uid = value
        lock.unlock()
    }

    func asAccountUIDProvider() -> ClosureAccountUIDProvider {
        ClosureAccountUIDProvider { [weak self] in self?.currentUID }
    }

    func asClosure() -> () -> String? {
        { [weak self] in self?.currentUID }
    }
}
