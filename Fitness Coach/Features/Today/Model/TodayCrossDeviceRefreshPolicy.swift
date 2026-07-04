//
//  TodayCrossDeviceRefreshPolicy.swift
//  Fitness Coach
//
//  Forma — Phase 5 cross-device refresh rules for the Today tab.
//
//  Reloads read merged SwiftData state. Phase 3 merge policy preserves newer
//  local pending edits — Today never applies remote payloads directly.
//

import Foundation

enum TodayCrossDeviceRefreshPolicy {

    static let relevantDomains: Set<AccountDataRefreshDomain> = [
        .today,
        .food,
        .water,
        .weight,
        .dailyReview,
        .plan,
        .profile
    ]

    /// Debounce window for coalescing rapid cross-device refresh events.
    static let reloadDebounceMilliseconds = 200

    static func shouldReload(for event: AccountDataRefreshEvent) -> Bool {
        !event.domains.isDisjoint(with: relevantDomains)
    }

    static func matchesCurrentUID(
        event: AccountDataRefreshEvent,
        ownerUIDProvider: () -> String?
    ) -> Bool {
        AccountDataRefreshEventSupport.matchesCurrentUID(
            event: event,
            currentUIDProvider: ownerUIDProvider
        )
    }
}
