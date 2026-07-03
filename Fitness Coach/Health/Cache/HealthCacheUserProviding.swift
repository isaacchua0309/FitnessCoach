//
//  HealthCacheUserProviding.swift
//  Fitness Coach
//
//  Forma — Supplies the active user id for scoped health cache storage.
//

import Foundation

protocol HealthCacheUserProviding: Sendable {
    func currentUserID() -> String?
}

struct StaticHealthCacheUserProvider: HealthCacheUserProviding {

    private let userID: String?

    init(userID: String?) {
        self.userID = userID
    }

    func currentUserID() -> String? {
        userID
    }
}

struct ClosureHealthCacheUserProvider: HealthCacheUserProviding {

    private let provider: @Sendable () -> String?

    init(provider: @escaping @Sendable () -> String?) {
        self.provider = provider
    }

    func currentUserID() -> String? {
        provider()
    }
}
