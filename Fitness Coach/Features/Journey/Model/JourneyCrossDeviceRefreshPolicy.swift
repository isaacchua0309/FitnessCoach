//
//  JourneyCrossDeviceRefreshPolicy.swift
//  Fitness Coach
//
//  Forma — Phase 5 cross-device refresh rules for the Journey tab.
//
//  Rebuilds read merged SwiftData state. Phase 3 merge policy preserves newer
//  local pending edits — Journey never applies remote payloads directly.
//

import Foundation

enum JourneyCrossDeviceRefreshPolicy {

    static let relevantDomains: Set<AccountDataRefreshDomain> = [
        .journey,
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
