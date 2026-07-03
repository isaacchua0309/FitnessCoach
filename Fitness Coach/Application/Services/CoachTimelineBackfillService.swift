//
//  CoachTimelineBackfillService.swift
//  Fitness Coach
//
//  Forma — Idempotent Coach timeline hydration from persisted logs and Health reads.
//
//  Safe to invoke on app launch or Coach open. Never invents chat messages or
//  missing Health data, and never blocks the caller on persistence failures.
//

import Foundation
import OSLog

// MARK: - Protocol

/// Hydrates the Coach timeline from existing persisted state.
protocol CoachTimelineBackfilling: Sendable {
    /// Backfills today's logs and the previous seven calendar days when safe.
    /// Idempotent and non-throwing.
    func runBackfill() async
}

// MARK: - Health query abstraction

/// Narrow Health read surface for timeline backfill tests and production wiring.
protocol CoachTimelineHealthActivityQuerying: Sendable {
    func workouts(from startDate: Date, to endDate: Date) async -> [HealthWorkoutRecord]
    func stepsToday(on date: Date, calendar: Calendar) async throws -> Int
}

extension HealthActivityQueryService: CoachTimelineHealthActivityQuerying {}

// MARK: - Service

@MainActor
final class CoachTimelineBackfillService: CoachTimelineBackfilling {

    /// Number of calendar days before today included in the lookback window.
    static let previousDaysLookback = 7

    /// Events with the same type, local day, and linked entry within this window are duplicates.
    static let timestampTolerance: TimeInterval = 60

    /// Minimum interval between backfill runs during active Coach context builds.
    static let minBackfillInterval: TimeInterval = 60

    private let timelineStore: (any CoachTimelineStoring)?
    private let foodLogService: FoodLogService?
    private let waterLogService: WaterLogService?
    private let weightLogService: WeightLogService?
    private let healthActivityQuery: (any CoachTimelineHealthActivityQuerying)?
    private let dateProvider: DateProviding
    private let calendar: Calendar
    private let logger = Logger(subsystem: "Forma", category: "CoachTimelineBackfill")
    private var lastBackfillAt: Date?

    init(
        timelineStore: (any CoachTimelineStoring)?,
        foodLogService: FoodLogService? = nil,
        waterLogService: WaterLogService? = nil,
        weightLogService: WeightLogService? = nil,
        healthActivityQuery: (any CoachTimelineHealthActivityQuerying)? = nil,
        dateProvider: DateProviding? = nil,
        calendar: Calendar = .current
    ) {
        self.timelineStore = timelineStore
        self.foodLogService = foodLogService
        self.waterLogService = waterLogService
        self.weightLogService = weightLogService
        self.healthActivityQuery = healthActivityQuery
        self.dateProvider = dateProvider ?? SystemDateProvider()
        self.calendar = calendar
    }

    func runBackfill() async {
        guard let timelineStore else { return }

        let now = dateProvider.now
        if let lastBackfillAt,
           now.timeIntervalSince(lastBackfillAt) < Self.minBackfillInterval {
            return
        }
        lastBackfillAt = now

        do {
            let referenceDate = now
            let dates = Self.backfillDates(endingOn: referenceDate, calendar: calendar)
            guard let oldestDay = dates.first, let newestDay = dates.last else { return }

            let rangeEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: newestDay))
                ?? referenceDate
            let existingEvents = try await timelineStore.events(from: oldestDay, to: rangeEnd)
            var deduplicator = CoachTimelineBackfillDeduplicator(
                existing: existingEvents,
                tolerance: Self.timestampTolerance
            )

            var newEvents: [CoachTimelineEvent] = []
            for date in dates {
                newEvents.append(contentsOf: try backfillFood(for: date, deduplicator: &deduplicator))
                newEvents.append(contentsOf: try backfillWater(for: date, deduplicator: &deduplicator))
                newEvents.append(contentsOf: try backfillWeight(for: date, deduplicator: &deduplicator))
                newEvents.append(contentsOf: await backfillWorkouts(for: date, deduplicator: &deduplicator))
                newEvents.append(contentsOf: await backfillSteps(for: date, deduplicator: &deduplicator))
            }

            guard !newEvents.isEmpty else { return }
            try await timelineStore.appendMany(newEvents)
        } catch {
            logger.error(
                "Coach timeline backfill failed: \(error.localizedDescription, privacy: .public)"
            )
            #if DEBUG
            FormaPipelineTracer.event(
                stage: .error,
                level: .error,
                message: "Coach timeline backfill failed",
                fields: ["error": error.localizedDescription]
            )
            #endif
        }
    }

    // MARK: Log backfill

    private func backfillFood(
        for date: Date,
        deduplicator: inout CoachTimelineBackfillDeduplicator
    ) throws -> [CoachTimelineEvent] {
        guard let foodLogService else { return [] }

        return try foodLogService.getFoodEntries(for: date).compactMap { entry in
            let event = makeBackfillEvent(
                type: .foodLogged,
                payload: .foodLogged(entry.backfillLoggedPayload()),
                occurredAt: entry.createdAt,
                link: CoachTimelineEventLink(
                    linkedEntryId: entry.id,
                    linkedDailyLogId: entry.dailyLogId
                )
            )
            return deduplicator.registerIfNew(event)
        }
    }

    private func backfillWater(
        for date: Date,
        deduplicator: inout CoachTimelineBackfillDeduplicator
    ) throws -> [CoachTimelineEvent] {
        guard let waterLogService else { return [] }

        return try waterLogService.getWaterEntries(for: date).compactMap { entry in
            let event = makeBackfillEvent(
                type: .waterLogged,
                payload: .waterLogged(
                    WaterLoggedPayload(
                        entryId: entry.id,
                        dailyLogId: entry.dailyLogId,
                        amountMl: entry.amountMl
                    )
                ),
                occurredAt: entry.createdAt,
                link: CoachTimelineEventLink(
                    linkedEntryId: entry.id,
                    linkedDailyLogId: entry.dailyLogId
                )
            )
            return deduplicator.registerIfNew(event)
        }
    }

    private func backfillWeight(
        for date: Date,
        deduplicator: inout CoachTimelineBackfillDeduplicator
    ) throws -> [CoachTimelineEvent] {
        guard let weightLogService else { return [] }

        let dayStart = calendar.startOfDay(for: date)
        return try weightLogService.getWeightEntries(from: dayStart, to: dayStart).compactMap { entry in
            let event = makeBackfillEvent(
                type: .weightLogged,
                payload: .weightLogged(
                    WeightLoggedPayload(
                        entryId: entry.id,
                        weightKg: entry.weightKg,
                        note: entry.note
                    )
                ),
                occurredAt: entry.createdAt,
                link: CoachTimelineEventLink(linkedEntryId: entry.id)
            )
            return deduplicator.registerIfNew(event)
        }
    }

    // MARK: Health backfill

    private func backfillWorkouts(
        for date: Date,
        deduplicator: inout CoachTimelineBackfillDeduplicator
    ) async -> [CoachTimelineEvent] {
        guard let healthActivityQuery else { return [] }

        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let workouts = await healthActivityQuery.workouts(from: dayStart, to: dayEnd)
        guard !workouts.isEmpty else { return [] }

        let totalDurationMinutes = workouts.reduce(0) { $0 + $1.durationMinutes }
        let activeCalories = workouts.compactMap(\.activeCalories).reduce(0, +)

        let event = makeBackfillEvent(
            type: .workoutDetected,
            payload: .workoutDetected(
                WorkoutDetectedPayload(
                    workoutCount: workouts.count,
                    totalDurationMinutes: totalDurationMinutes,
                    totalActiveCalories: activeCalories > 0 ? activeCalories : nil,
                    primaryWorkoutTitle: workouts.first?.activityName,
                    demand: nil
                )
            ),
            occurredAt: workouts.map(\.startDate).max() ?? dayStart,
            link: CoachTimelineEventLink()
        )
        return deduplicator.registerIfNew(event).map { [$0] } ?? []
    }

    private func backfillSteps(
        for date: Date,
        deduplicator: inout CoachTimelineBackfillDeduplicator
    ) async -> [CoachTimelineEvent] {
        guard let healthActivityQuery else { return [] }

        let steps: Int
        do {
            steps = try await healthActivityQuery.stepsToday(on: date, calendar: calendar)
        } catch {
            if HealthKitOptionalAccessPolicy.isOptionalAccessFailure(error) {
                return []
            }
            logger.debug(
                "Skipping steps backfill for \(Self.localDateString(for: date, calendar: calendar), privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return []
        }

        let event = makeBackfillEvent(
            type: .stepsUpdated,
            payload: .steps(StepsPayload(steps: steps)),
            occurredAt: calendar.startOfDay(for: date),
            link: CoachTimelineEventLink()
        )
        return deduplicator.registerIfNew(event).map { [$0] } ?? []
    }

    // MARK: Event factory

    private func makeBackfillEvent(
        type: CoachTimelineEventType,
        payload: CoachTimelineEventPayload,
        occurredAt: Date,
        link: CoachTimelineEventLink
    ) -> CoachTimelineEvent {
        CoachTimelineEvent.make(
            type: type,
            source: .system,
            sourceAttribution: .systemBackfill,
            status: .confirmed,
            payload: payload,
            occurredAt: occurredAt,
            calendar: calendar,
            link: link
        )
    }

    // MARK: Date helpers

    static func backfillDates(endingOn referenceDate: Date, calendar: Calendar) -> [Date] {
        let todayStart = calendar.startOfDay(for: referenceDate)
        let offsets = (0...previousDaysLookback).reversed()
        return offsets.compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: todayStart)
        }
    }

    static func localDateString(for date: Date, calendar: Calendar) -> String {
        CoachTimelineEvent.makeTimestamps(from: date, calendar: calendar).localDate
    }
}

// MARK: - Deduplication

struct CoachTimelineBackfillDeduplicator {

    private let tolerance: TimeInterval
    private var recorded: [CoachTimelineEvent]

    init(existing: [CoachTimelineEvent], tolerance: TimeInterval) {
        self.tolerance = tolerance
        self.recorded = existing
    }

    mutating func registerIfNew(_ candidate: CoachTimelineEvent) -> CoachTimelineEvent? {
        guard !isDuplicate(candidate) else { return nil }
        recorded.append(candidate)
        return candidate
    }

    func isDuplicate(_ candidate: CoachTimelineEvent) -> Bool {
        recorded.contains { existing in
            Self.isDuplicate(existing: existing, candidate: candidate, tolerance: tolerance)
        }
    }

    static func isDuplicate(
        existing: CoachTimelineEvent,
        candidate: CoachTimelineEvent,
        tolerance: TimeInterval
    ) -> Bool {
        guard existing.type == candidate.type else { return false }
        guard existing.localDate == candidate.localDate else { return false }

        switch candidate.type {
        case .foodLogged, .waterLogged, .weightLogged:
            guard let candidateEntryId = candidate.linkedEntryId else { return false }
            guard existing.linkedEntryId == candidateEntryId else { return false }
            return abs(existing.utcTimestamp.timeIntervalSince(candidate.utcTimestamp)) <= tolerance

        case .workoutDetected, .stepsUpdated:
            return true

        default:
            return false
        }
    }
}

// MARK: - Mapping

private extension FoodEntry {

    func backfillLoggedPayload() -> FoodLoggedPayload {
        FoodLoggedPayload(
            entryId: id,
            dailyLogId: dailyLogId,
            mealType: mealType?.rawValue,
            name: name,
            quantity: quantity,
            unit: unit,
            calories: calories,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            source: source.rawValue,
            isEdit: false,
            isDelete: false
        )
    }
}
