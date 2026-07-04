//
//  PlanCrossDeviceRefreshPolicy.swift
//  Fitness Coach
//
//  Forma — Phase 5 cross-device refresh rules for the Plan tab.
//
//  Reloads read merged SwiftData state. Profile merge preserves newer local
//  pending edits — Plan never applies remote payloads directly.
//

import Foundation

enum PlanCrossDeviceRefreshPolicy {

    static let relevantDomains: Set<AccountDataRefreshDomain> = [
        .plan,
        .profile,
        .today,
        .weight,
        .dailyReview,
        .food,
        .water
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
