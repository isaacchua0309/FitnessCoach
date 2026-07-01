//
//  TodayHydrationGate.swift
//  Fitness Coach
//
//  Signed-in user context required before Today loads or refreshes daily logs.
//

import Foundation

struct TodayHydrationContext: Equatable, Sendable {
    let sessionUID: String
    let profileOwnerUID: String
    let dailyLogDateKey: Date
}

enum TodayHydrationGate {

    /// Returns a hydration context only when the signed-in session owns the on-device profile.
    static func resolve(
        authState: AuthState,
        profile: UserProfile?,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> TodayHydrationContext? {
        guard case .signedIn(let uid) = authState else { return nil }
        guard let profile, let ownerUID = profile.ownerUID, ownerUID == uid else { return nil }

        return TodayHydrationContext(
            sessionUID: uid,
            profileOwnerUID: ownerUID,
            dailyLogDateKey: calendar.startOfDay(for: now)
        )
    }
}
