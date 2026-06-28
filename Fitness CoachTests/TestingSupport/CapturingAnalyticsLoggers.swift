//
//  CapturingAnalyticsLoggers.swift
//  Fitness CoachTests
//
//  Shared in-memory analytics loggers for unit tests (no Firebase).
//

import Foundation
@testable import Fitness_Coach

final class CapturingOnboardingAnalyticsLogger: OnboardingAnalyticsLogging, @unchecked Sendable {

    struct Record: Sendable {
        let event: OnboardingAnalyticsEvent
        let properties: OnboardingAnalyticsProperties
    }

    private let lock = NSLock()
    private var records: [Record] = []

    func log(_ event: OnboardingAnalyticsEvent, properties: OnboardingAnalyticsProperties) {
        lock.lock()
        records.append(Record(event: event, properties: properties))
        lock.unlock()
    }

    func contains(_ event: OnboardingAnalyticsEvent, step: String? = nil) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return records.contains { record in
            guard record.event == event else { return false }
            if let step, record.properties.step != step { return false }
            return true
        }
    }

    func lastProperties(for event: OnboardingAnalyticsEvent) -> [String: String]? {
        lock.lock()
        defer { lock.unlock() }
        guard let record = records.last(where: { $0.event == event }) else { return nil }
        return record.properties.asParameters()
    }
}

final class CapturingTodayAnalyticsLogger: TodayAnalyticsLogging, @unchecked Sendable {
    struct Event {
        let event: TodayAnalyticsEvent
        let properties: TodayAnalyticsProperties
    }

    private(set) var events: [Event] = []

    func log(_ event: TodayAnalyticsEvent, properties: TodayAnalyticsProperties) {
        events.append(Event(event: event, properties: properties))
    }
}

final class CapturingPlanAnalyticsLogger: PlanAnalyticsLogging, @unchecked Sendable {
    struct Entry {
        let event: PlanAnalyticsEvent
        let properties: PlanAnalyticsProperties
    }

    private(set) var events: [Entry] = []

    func log(_ event: PlanAnalyticsEvent, properties: PlanAnalyticsProperties) {
        events.append(Entry(event: event, properties: properties))
    }
}

final class CapturingJourneyAnalyticsLogger: JourneyAnalyticsLogging, @unchecked Sendable {
    struct Entry {
        let event: JourneyAnalyticsEvent
        let properties: JourneyAnalyticsProperties
    }

    private(set) var events: [Entry] = []

    var lastEvent: JourneyAnalyticsEvent? { events.last?.event }
    var lastProperties: [String: String]? { events.last?.properties.asParameters() }

    func log(_ event: JourneyAnalyticsEvent, properties: JourneyAnalyticsProperties) {
        events.append(Entry(event: event, properties: properties))
    }
}

final class CapturingPublicEntryAnalyticsLogger: PublicEntryAnalyticsLogging, @unchecked Sendable {
    struct Entry {
        let event: PublicEntryAnalyticsEvent
        let properties: PublicEntryAnalyticsProperties
    }

    private(set) var events: [Entry] = []

    var lastProperties: [String: String]? { events.last?.properties.asParameters() }

    func log(_ event: PublicEntryAnalyticsEvent, properties: PublicEntryAnalyticsProperties) {
        events.append(Entry(event: event, properties: properties))
    }

    func contains(_ event: PublicEntryAnalyticsEvent) -> Bool {
        events.contains { $0.event == event }
    }

    func lastProperties(for event: PublicEntryAnalyticsEvent) -> [String: String]? {
        events.last { $0.event == event }?.properties.asParameters()
    }
}

final class CapturingThemeAnalyticsLogger: ThemeAnalyticsLogging, @unchecked Sendable {
    struct Entry {
        let event: ThemeAnalyticsEvent
        let properties: ThemeAnalyticsProperties
    }

    private(set) var events: [Entry] = []

    var lastProperties: [String: String]? { events.last?.properties.asParameters() }

    func log(_ event: ThemeAnalyticsEvent, properties: ThemeAnalyticsProperties) {
        events.append(Entry(event: event, properties: properties))
    }

    func contains(_ event: ThemeAnalyticsEvent) -> Bool {
        events.contains { $0.event == event }
    }

    func lastProperties(for event: ThemeAnalyticsEvent) -> [String: String]? {
        events.last { $0.event == event }?.properties.asParameters()
    }
}

extension OnboardingAnalyticsProperties {
    subscript(key: String) -> String? {
        asParameters()[key]
    }
}
