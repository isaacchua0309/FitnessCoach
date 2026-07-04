//
//  AccountDataRefreshEventBus.swift
//  Fitness Coach
//
//  Forma — Domain-scoped refresh events after cross-device sync (Phase 5).
//
//  Events carry UID and affected domains only — no food names, macros, or weights.
//

import Combine
import Foundation

enum AccountDataRefreshDomain: String, Codable, Equatable, Sendable, CaseIterable {
    case profile
    case plan
    case today
    case journey
    case food
    case water
    case weight
    case dailyReview
    case coachContext
}

struct AccountDataRefreshEvent: Equatable, Sendable {
    let uid: String
    let domains: Set<AccountDataRefreshDomain>
    let reason: CrossDeviceSyncReason
    let createdAt: Date
}

protocol AccountDataRefreshPublishing: AnyObject {
    func publish(_ event: AccountDataRefreshEvent)
}

protocol AccountDataRefreshSubscribing: AnyObject {
    var events: AnyPublisher<AccountDataRefreshEvent, Never> { get }
}

enum AccountDataRefreshEventSupport {

    /// Maps cross-device sync outcomes to privacy-safe refresh domains.
    static func domains(
        uploadedMutations: Int,
        pullSummary: CrossDeviceSyncSummary
    ) -> Set<AccountDataRefreshDomain> {
        var domains = Set<AccountDataRefreshDomain>()
        let hasMergeActivity = pullSummary.inserted + pullSummary.updated + pullSummary.deleted > 0

        if pullSummary.pulledProfile {
            domains.insert(.profile)
            domains.insert(.plan)
        }
        if pullSummary.pulledDailyLogs > 0 && hasMergeActivity {
            domains.insert(.today)
        }
        if pullSummary.pulledFoodEntries > 0 && hasMergeActivity {
            domains.insert(.food)
            domains.insert(.today)
            domains.insert(.coachContext)
        }
        if pullSummary.pulledWaterEntries > 0 && hasMergeActivity {
            domains.insert(.water)
            domains.insert(.today)
            domains.insert(.coachContext)
        }
        if pullSummary.pulledWeightEntries > 0 && hasMergeActivity {
            domains.insert(.weight)
            domains.insert(.journey)
        }
        if pullSummary.pulledDailyReviews > 0 && hasMergeActivity {
            domains.insert(.dailyReview)
            domains.insert(.journey)
        }

        if uploadedMutations > 0 {
            domains.formUnion([.today, .journey, .coachContext])
        }

        if hasMergeActivity && domains.isEmpty {
            domains.formUnion([.today, .journey, .coachContext])
        }

        return domains
    }

    static func matchesCurrentUID(
        event: AccountDataRefreshEvent,
        currentUIDProvider: () -> String?
    ) -> Bool {
        guard let currentUID = normalizedUID(from: currentUIDProvider()) else { return false }
        return event.uid == currentUID
    }

    static func normalizedUID(from raw: String?) -> String? {
        guard let raw else { return nil }
        return try? AccountSyncMutationValidation.normalizedOwnerUID(raw)
    }
}

extension Publisher where Output == AccountDataRefreshEvent, Failure == Never {

    /// Drops refresh events that do not belong to the active signed-in account.
    func filterForCurrentAccountUID(
        _ currentUIDProvider: @escaping () -> String?
    ) -> AnyPublisher<AccountDataRefreshEvent, Never> {
        compactMap { event in
            AccountDataRefreshEventSupport.matchesCurrentUID(
                event: event,
                currentUIDProvider: currentUIDProvider
            ) ? event : nil
        }
        .eraseToAnyPublisher()
    }

    func filterForDomain(_ domain: AccountDataRefreshDomain) -> AnyPublisher<AccountDataRefreshEvent, Never> {
        filter { $0.domains.contains(domain) }
            .eraseToAnyPublisher()
    }
}

@MainActor
final class AccountDataRefreshEventBus: AccountDataRefreshPublishing, AccountDataRefreshSubscribing {

    private let subject = PassthroughSubject<AccountDataRefreshEvent, Never>()
    private let coalesceInterval: Duration
    private let nowProvider: () -> Date
    private var coalesceTask: Task<Void, Never>?
    private var pendingEvent: AccountDataRefreshEvent?

    init(
        coalesceInterval: Duration = .milliseconds(100),
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.coalesceInterval = coalesceInterval
        self.nowProvider = nowProvider
    }

    var events: AnyPublisher<AccountDataRefreshEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    func publish(_ event: AccountDataRefreshEvent) {
        guard !event.domains.isEmpty else { return }

        if let pending = pendingEvent, pending.uid == event.uid {
            pendingEvent = AccountDataRefreshEvent(
                uid: event.uid,
                domains: pending.domains.union(event.domains),
                reason: event.reason,
                createdAt: nowProvider()
            )
        } else {
            flushPending()
            pendingEvent = event
        }
        scheduleCoalescedFlush()
    }

    func flushImmediately() {
        coalesceTask?.cancel()
        coalesceTask = nil
        flushPending()
    }

    private func scheduleCoalescedFlush() {
        coalesceTask?.cancel()
        coalesceTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.coalesceInterval)
            guard !Task.isCancelled else { return }
            self.flushPending()
        }
    }

    private func flushPending() {
        guard let event = pendingEvent else { return }
        pendingEvent = nil
        subject.send(event)
    }
}
