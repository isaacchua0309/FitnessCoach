//
//  CoachContextPacketV2Builder.swift
//  Fitness Coach
//
//  Forma — Assembles CoachContextPacketV2 from authoritative app state and timeline.
//
//  Read-only: never mutates nutrition truth. Individual source failures degrade
//  into `missingData` instead of crashing the caller.
//

import Foundation
import OSLog

@MainActor
struct CoachContextPacketV2Builder {

    static let defaultTimelineEventLimit = 20
    static let recentChatMessageLimit = 12
    static let sparseTodayEventThreshold = 4
    static let crossDayLookbackDays = 7
    static let commonFoodLookbackDays = 30

    private let dailyLogService: DailyLogService?
    private let foodLogService: FoodLogService?
    private let waterLogService: WaterLogService?
    private let weightLogService: WeightLogService?
    private let userProfileService: (any UserProfileReading)?
    private let healthActivityQuery: HealthActivityQueryService?
    private let healthIntelligenceSnapshotProvider: (any HealthIntelligenceSnapshotServing)?
    private let healthIntelligenceContextBuilder: (any HealthIntelligenceContextBuilding)?
    private let trainingLoadEngine: (any TrainingLoadProviding)?
    private let timelineStore: (any CoachTimelineStoring)?
    private let timelineBackfillService: (any CoachTimelineBackfilling)?
    private let timelineRecorder: (any CoachTimelineRecording)?
    private let dateProvider: DateProviding
    private let calendar: Calendar
    private let loadHealthIntelligence: () -> Bool
    private let healthIntelligenceLoadTimeout: Duration
    private let healthIntelligenceSnapshotLoad: (@Sendable (_ date: Date, _ calendar: Calendar) async -> CoachHealthIntelligenceSnapshotLoadOutcome)?
    private let logger = Logger(subsystem: "Forma", category: "CoachContextPacketV2")

    init(
        dailyLogService: DailyLogService? = nil,
        foodLogService: FoodLogService? = nil,
        waterLogService: WaterLogService? = nil,
        weightLogService: WeightLogService? = nil,
        userProfileService: (any UserProfileReading)? = nil,
        healthActivityQuery: HealthActivityQueryService? = nil,
        healthIntelligenceSnapshotProvider: (any HealthIntelligenceSnapshotServing)? = nil,
        healthIntelligenceContextBuilder: (any HealthIntelligenceContextBuilding)? = nil,
        trainingLoadEngine: (any TrainingLoadProviding)? = nil,
        timelineStore: (any CoachTimelineStoring)? = nil,
        timelineBackfillService: (any CoachTimelineBackfilling)? = nil,
        timelineRecorder: (any CoachTimelineRecording)? = nil,
        dateProvider: DateProviding? = nil,
        calendar: Calendar = .current,
        loadHealthIntelligence: @escaping () -> Bool = { HealthIntelligenceFeatureFlags.shouldCoachLoadHealthIntelligence },
        healthIntelligenceLoadTimeout: Duration = CoachHealthIntelligenceSnapshotLoader.defaultTimeout,
        healthIntelligenceSnapshotLoad: (@Sendable (_ date: Date, _ calendar: Calendar) async -> CoachHealthIntelligenceSnapshotLoadOutcome)? = nil
    ) {
        self.dailyLogService = dailyLogService
        self.foodLogService = foodLogService
        self.waterLogService = waterLogService
        self.weightLogService = weightLogService
        self.userProfileService = userProfileService
        self.healthActivityQuery = healthActivityQuery
        self.healthIntelligenceSnapshotProvider = healthIntelligenceSnapshotProvider
        self.healthIntelligenceContextBuilder = healthIntelligenceContextBuilder
        self.trainingLoadEngine = trainingLoadEngine
        self.timelineStore = timelineStore
        self.timelineBackfillService = timelineBackfillService
        self.timelineRecorder = timelineRecorder
        self.dateProvider = dateProvider ?? SystemDateProvider()
        self.calendar = calendar
        self.loadHealthIntelligence = loadHealthIntelligence
        self.healthIntelligenceLoadTimeout = healthIntelligenceLoadTimeout
        self.healthIntelligenceSnapshotLoad = healthIntelligenceSnapshotLoad
    }

    func makeContext(
        recentMessages: [ChatMessage],
        currentUserMessage: String? = nil,
        mode: CoachContextGenerationMode = .live
    ) async -> CoachContextPacketV2 {
        let now = dateProvider.now
        let todayLocalDate = CoachContextMeta.make(generatedAt: now, calendar: calendar).localDate
        var readFailures = 0

        await timelineBackfillService?.runBackfill()

        var assumptions: [CoachAssumptionContext] = []
        var sources: [String] = []
        var healthAccessDenied = false
        var healthUnavailable = false
        var healthIntelligenceTimedOut = false
        var healthIntelligenceFailed = false

        let profile = makeProfileContext(sources: &sources)
        let dailyLog = readTodayLog(sources: &sources, readFailures: &readFailures)

        let foodEntries = readFoodEntries(for: now, sources: &sources, readFailures: &readFailures)
        _ = readWaterEntries(for: now, sources: &sources, readFailures: &readFailures)
        let weightEntries = readWeightEntries(for: now, sources: &sources, readFailures: &readFailures)

        let healthSnapshotLoad = await loadHealthSnapshot(
            on: now,
            healthUnavailable: &healthUnavailable,
            healthIntelligenceTimedOut: &healthIntelligenceTimedOut,
            healthIntelligenceFailed: &healthIntelligenceFailed
        )
        let healthSnapshot = healthSnapshotLoad.snapshot
        let trainingLoad = await loadTrainingLoad(on: now)
        let workoutsResult = await readWorkouts(
            on: now,
            healthAccessDenied: &healthAccessDenied,
            healthUnavailable: &healthUnavailable,
            sources: &sources
        )
        let stepsResult = await readSteps(
            on: now,
            snapshot: healthSnapshot,
            healthAccessDenied: &healthAccessDenied,
            healthUnavailable: &healthUnavailable,
            sources: &sources
        )

        let healthIntelligence = makeHealthIntelligence(
            from: healthSnapshot,
            trainingLoad: trainingLoad
        )
        if healthIntelligence != nil {
            sources.append("healthIntelligence")
        }

        let today = makeTodayPacket(
            dailyLog: dailyLog,
            foodEntries: foodEntries,
            weightEntries: weightEntries,
            steps: stepsResult,
            workoutsResult: workoutsResult
        )
        let training = makeTrainingContext(
            workoutsResult: workoutsResult,
            healthIntelligence: healthIntelligence,
            healthSnapshot: healthSnapshot,
            trainingLoad: trainingLoad
        )

        let timelineEvents = await loadTimelineEvents(
            now: now,
            todayLocalDate: todayLocalDate,
            readFailures: &readFailures
        )
        let timelineContextEvents = CoachContextPacketV2TimelineSelector.makeContextEvents(
            from: timelineEvents,
            todayLocalDate: todayLocalDate,
            limit: Self.defaultTimelineEventLimit
        )

        let chatContext = makeChatContext(
            from: recentMessages,
            currentUserMessage: currentUserMessage,
            timelineEvents: timelineEvents
        )
        let foodHistory = loadFoodHistory(endingOn: now, sources: &sources)
        let recentMeals = CoachContextFoodMemoryBuilder.makeRecentMeals(
            from: foodHistory,
            todayLocalDate: todayLocalDate,
            calendar: calendar
        )
        let commonFoods = CoachContextFoodMemoryBuilder.makeCommonFoods(from: foodHistory)

        var missingData = makeMissingData(
            stepsResult: stepsResult,
            workoutsResult: workoutsResult,
            healthAccessDenied: healthAccessDenied,
            healthUnavailable: healthUnavailable,
            healthIntelligenceTimedOut: healthIntelligenceTimedOut,
            healthIntelligenceFailed: healthIntelligenceFailed,
            healthIntelligence: healthIntelligence,
            healthSnapshot: healthSnapshot,
            recentMealCount: recentMeals.count,
            weightEntries: weightEntries,
            dailyLog: dailyLog,
            timelineEventCount: timelineContextEvents.count
        )

        assumptions.append(contentsOf: makeAssumptions(
            stepsResult: stepsResult,
            workoutsResult: workoutsResult,
            timelineBackfillRan: timelineBackfillService != nil,
            healthIntelligenceTimedOut: healthIntelligenceTimedOut,
            healthIntelligenceFailed: healthIntelligenceFailed
        ))

        if dailyLog != nil { sources.append("swiftData") }
        if timelineStore != nil { sources.append("coachTimeline") }
        if healthActivityQuery != nil { sources.append("healthKit") }

        let effectiveMode = resolveGenerationMode(
            requested: mode,
            readFailures: readFailures,
            healthAccessDenied: healthAccessDenied,
            healthUnavailable: healthUnavailable,
            healthIntelligenceTimedOut: healthIntelligenceTimedOut,
            healthIntelligenceFailed: healthIntelligenceFailed,
            dailyLogServiceAvailable: dailyLogService != nil,
            dailyLogLoaded: dailyLog != nil
        )

        var packet = CoachContextPacketV2(
            meta: CoachContextMeta.make(generatedAt: now, calendar: calendar),
            profile: profile,
            today: today,
            training: training,
            healthIntelligence: healthIntelligence,
            timeline: CoachContextTimelinePacket(recentEvents: timelineContextEvents),
            recentChatMessages: chatContext.recentChatMessages,
            currentUserMessage: chatContext.currentUserMessage,
            recentMealsStructured: Array(recentMeals),
            commonFoods: commonFoods,
            missingData: missingData,
            assumptions: assumptions,
            generationMode: effectiveMode,
            sourceAttribution: CoachContextSourceAttribution(
                generationMode: effectiveMode,
                timelineEventCount: timelineContextEvents.count,
                recentMealCount: recentMeals.count,
                commonFoodCount: commonFoods.count,
                healthIntelligenceIncluded: healthIntelligence != nil,
                sources: Array(Set(sources)).sorted()
            )
        )

        packet = CoachContextPacketV2SizeCompactor.compact(packet)

        recordHealthTimelineEvents(
            workoutsResult: workoutsResult,
            stepsResult: stepsResult,
            healthIntelligence: healthIntelligence,
            healthAccessDenied: healthAccessDenied,
            healthUnavailable: healthUnavailable,
            now: now
        )
        recordContextGenerated(packet: packet, mode: effectiveMode, now: now)

        FormaPipelineTracer.event(
            stage: .context,
            level: .debug,
            message: "CoachContextPacketV2 assembled",
            fields: [
                "mode": mode.rawValue,
                "timelineEvents": String(packet.timeline.recentEvents.count),
                "chatMessages": String(packet.recentChatMessages.count),
                "bytes": String(packet.estimatedEncodedByteCount()),
                "missingSignals": String(packet.missingData.missingSignalLabels.count),
                "healthIntelligenceTimedOut": String(healthIntelligenceTimedOut),
                "healthIntelligenceFailed": String(healthIntelligenceFailed),
                "healthIntelligenceIncluded": String(packet.healthIntelligence != nil)
            ]
        )

        let validated = CoachContextCorrectnessValidator.validateAndCorrect(
            packet,
            calendar: calendar
        )
        if !validated.isValid {
            FormaPipelineTracer.event(
                stage: .context,
                level: .warn,
                message: "CoachContextPacketV2 validation corrected issues",
                fields: [
                    "issueCount": String(validated.issues.count),
                    "rules": validated.issues.map(\.rule.rawValue).joined(separator: ",")
                ]
            )
        }

        return validated.correctedPacket
    }

    // MARK: Reads

    private func readTodayLog(sources: inout [String], readFailures: inout Int) -> DailyLog? {
        guard let dailyLogService else { return nil }
        do {
            let log = try dailyLogService.getTodayLog()
            sources.append("dailyLog")
            return log
        } catch {
            logReadFailure("dailyLog", error: error, readFailures: &readFailures)
            return nil
        }
    }

    private func readFoodEntries(for date: Date, sources: inout [String], readFailures: inout Int) -> [FoodEntry] {
        guard let foodLogService else { return [] }
        do {
            let entries = try foodLogService.getFoodEntries(for: date)
            if !entries.isEmpty { sources.append("foodLog") }
            return entries
        } catch {
            logReadFailure("foodLog", error: error, readFailures: &readFailures)
            return []
        }
    }

    private func loadFoodHistory(endingOn date: Date, sources: inout [String]) -> [FoodEntry] {
        guard let foodLogService else { return [] }

        let todayStart = calendar.startOfDay(for: date)
        guard let lookbackStart = calendar.date(
            byAdding: .day,
            value: -(Self.commonFoodLookbackDays - 1),
            to: todayStart
        ) else {
            return []
        }

        do {
            let entries = try foodLogService.getFoodEntries(
                from: lookbackStart,
                to: date,
                calendar: calendar
            )
            if !entries.isEmpty {
                sources.append("foodLogHistory")
            }
            return entries
        } catch {
            logReadFailure("foodLogHistory", error: error)
            return []
        }
    }

    private func readWaterEntries(for date: Date, sources: inout [String], readFailures: inout Int) -> [WaterEntry] {
        guard let waterLogService else { return [] }
        do {
            let entries = try waterLogService.getWaterEntries(for: date)
            if !entries.isEmpty { sources.append("waterLog") }
            return entries
        } catch {
            logReadFailure("waterLog", error: error, readFailures: &readFailures)
            return []
        }
    }

    private func readWeightEntries(for date: Date, sources: inout [String], readFailures: inout Int) -> [WeightEntry] {
        guard let weightLogService else { return [] }
        let dayStart = calendar.startOfDay(for: date)
        do {
            let entries = try weightLogService.getWeightEntries(from: dayStart, to: dayStart)
            if !entries.isEmpty { sources.append("weightLog") }
            return entries
        } catch {
            logReadFailure("weightLog", error: error, readFailures: &readFailures)
            return []
        }
    }

    private struct HealthSnapshotLoadResult {
        var snapshot: HealthIntelligenceSnapshot?
    }

    private func loadHealthSnapshot(
        on date: Date,
        healthUnavailable: inout Bool,
        healthIntelligenceTimedOut: inout Bool,
        healthIntelligenceFailed: inout Bool
    ) async -> HealthSnapshotLoadResult {
        guard loadHealthIntelligence() else {
            return HealthSnapshotLoadResult(snapshot: nil)
        }

        let outcome: CoachHealthIntelligenceSnapshotLoadOutcome
        if let healthIntelligenceSnapshotLoad {
            outcome = await healthIntelligenceSnapshotLoad(date, calendar)
        } else if let healthIntelligenceSnapshotProvider {
            outcome = await CoachHealthIntelligenceSnapshotLoader.load(
                timeout: healthIntelligenceLoadTimeout
            ) {
                await healthIntelligenceSnapshotProvider.loadTodaySnapshot(
                    for: date,
                    calendar: calendar
                )
            }
        } else {
            return HealthSnapshotLoadResult(snapshot: nil)
        }

        switch outcome {
        case .success(let snapshot):
            if snapshot == nil {
                healthUnavailable = true
            }
            return HealthSnapshotLoadResult(snapshot: snapshot)
        case .timedOut:
            healthUnavailable = true
            healthIntelligenceTimedOut = true
            logger.debug(
                "CoachContextPacketV2 healthIntelligence timed out; continuing with basic HealthKit context"
            )
            return HealthSnapshotLoadResult(snapshot: nil)
        case .failed(let reason):
            healthUnavailable = true
            healthIntelligenceFailed = true
            logger.debug(
                "CoachContextPacketV2 healthIntelligence failed reason=\(reason, privacy: .public); continuing with basic HealthKit context"
            )
            return HealthSnapshotLoadResult(snapshot: nil)
        }
    }

    private func loadTrainingLoad(on date: Date) async -> TrainingLoadSummary? {
        guard loadHealthIntelligence(),
              let healthIntelligenceContextBuilder,
              let trainingLoadEngine else {
            return nil
        }

        let context = await healthIntelligenceContextBuilder.buildContext(for: date, calendar: calendar)
        return try? trainingLoadEngine.evaluate(context.trainingLoadInput)
    }

    private struct WorkoutsReadResult {
        var workouts: [HealthWorkoutRecord]
        var availability: HealthWorkoutsReadAvailability
        var source: String

        var isKnown: Bool { availability == .available }
    }

    private func readWorkouts(
        on date: Date,
        healthAccessDenied: inout Bool,
        healthUnavailable: inout Bool,
        sources: inout [String]
    ) async -> WorkoutsReadResult {
        guard let healthActivityQuery else {
            healthUnavailable = true
            return WorkoutsReadResult(workouts: [], availability: .unavailable, source: "none")
        }

        let result = await healthActivityQuery.readWorkoutsToday(on: date, calendar: calendar)
        switch result.availability {
        case .available:
            break
        case .accessDenied:
            healthAccessDenied = true
        case .unavailable:
            healthUnavailable = true
        }

        if !result.workouts.isEmpty {
            sources.append("healthWorkouts")
        }

        return WorkoutsReadResult(
            workouts: result.workouts,
            availability: result.availability,
            source: result.source
        )
    }

    private struct StepsReadResult {
        var value: Int?
        var source: String?
        var asOf: Date?
        var confidence: CoachContextConfidence
        var accessDenied: Bool
        var unavailable: Bool
    }

    private func readSteps(
        on date: Date,
        snapshot: HealthIntelligenceSnapshot?,
        healthAccessDenied: inout Bool,
        healthUnavailable: inout Bool,
        sources: inout [String]
    ) async -> StepsReadResult {
        if let healthActivityQuery {
            do {
                let steps = try await healthActivityQuery.stepsToday(on: date, calendar: calendar)
                sources.append("healthSteps")
                return StepsReadResult(
                    value: steps,
                    source: "healthKit",
                    asOf: dateProvider.now,
                    confidence: .medium,
                    accessDenied: false,
                    unavailable: false
                )
            } catch {
                if HealthKitOptionalAccessPolicy.isOptionalAccessFailure(error) {
                    healthAccessDenied = true
                    return StepsReadResult(
                        value: nil,
                        source: nil,
                        asOf: nil,
                        confidence: .unknown,
                        accessDenied: true,
                        unavailable: false
                    )
                }
                healthUnavailable = true
                logReadFailure("steps", error: error)
            }
        } else {
            healthUnavailable = true
        }

        if let steps = snapshot?.activity.steps {
            sources.append("healthIntelligenceSteps")
            return StepsReadResult(
                value: steps,
                source: "healthIntelligence",
                asOf: dateProvider.now,
                confidence: .low,
                accessDenied: false,
                unavailable: healthUnavailable
            )
        }

        return StepsReadResult(
            value: nil,
            source: nil,
            asOf: nil,
            confidence: .unknown,
            accessDenied: healthAccessDenied,
            unavailable: healthUnavailable || healthActivityQuery == nil
        )
    }

    private func loadTimelineEvents(
        now: Date,
        todayLocalDate: String,
        readFailures: inout Int
    ) async -> [CoachTimelineEvent] {
        guard let timelineStore else { return [] }

        do {
            var todayEvents = try await timelineStore.events(forLocalDate: todayLocalDate)
            let todayCount = todayEvents.count

            if todayCount < Self.sparseTodayEventThreshold {
                let lookbackStart = calendar.date(
                    byAdding: .day,
                    value: -Self.crossDayLookbackDays,
                    to: calendar.startOfDay(for: now)
                ) ?? now
                let rangeEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
                let ranged = try await timelineStore.events(from: lookbackStart, to: rangeEnd)

                var merged: [UUID: CoachTimelineEvent] = [:]
                for event in ranged + todayEvents {
                    merged[event.id] = event
                }
                todayEvents = merged.values.sorted { $0.utcTimestamp < $1.utcTimestamp }
            }

            return todayEvents.filter { CoachContextPacketV2TimelineSelector.isContextEligible($0) }
        } catch {
            logReadFailure("timeline", error: error, readFailures: &readFailures)
            return []
        }
    }

    // MARK: Builders

    private func makeProfileContext(sources: inout [String]) -> CoachUserProfileContext? {
        guard let profile = try? userProfileService?.getCurrentProfile() else { return nil }
        sources.append("profile")
        return CoachUserProfileContext(
            age: profile.age,
            sex: profile.sex,
            heightCm: profile.heightCm,
            currentWeightKg: profile.currentWeightKg,
            goalWeightKg: profile.goalWeightKg,
            activityLevel: profile.activityLevel,
            trainingFrequencyPerWeek: profile.trainingFrequencyPerWeek,
            goalType: Self.goalType(for: profile)
        )
    }

    private func makeHealthIntelligence(
        from snapshot: HealthIntelligenceSnapshot?,
        trainingLoad: TrainingLoadSummary?
    ) -> CoachHealthIntelligenceContext? {
        guard loadHealthIntelligence() else { return nil }

        let resolvedTrainingLoad = trainingLoad ?? .unknown
        let day = calendar.startOfDay(for: dateProvider.now)

        guard let snapshot else {
            return CoachHealthIntelligenceContext.unavailable(
                for: day,
                missingSignals: ["health intelligence snapshot"]
            )
        }

        let provisional = CoachHealthIntelligenceContextBuilder.build(
            from: snapshot,
            trainingLoad: resolvedTrainingLoad,
            calendar: calendar
        )
        let awareness = CoachAIActivityContextResolver.healthIntelligenceAwarenessAvailable(
            snapshot: snapshot,
            healthIntelligence: provisional
        )
        return CoachHealthIntelligenceContextBuilder.build(
            from: snapshot,
            trainingLoad: resolvedTrainingLoad,
            input: CoachHealthIntelligenceContextBuilder.BuildInput(
                awarenessAvailable: awareness
            ),
            calendar: calendar
        )
    }

    private func makeTodayPacket(
        dailyLog: DailyLog?,
        foodEntries: [FoodEntry],
        weightEntries: [WeightEntry],
        steps: StepsReadResult,
        workoutsResult: WorkoutsReadResult
    ) -> CoachContextTodayPacket? {
        guard let dailyLog else { return nil }

        let nutrition = DailyNutritionSummaryBuilder.build(from: dailyLog)
        let weightKg = weightEntries.last?.weightKg ?? dailyLog.weightKg
        let workoutCalories = workoutsResult.workouts.compactMap(\.activeCalories).reduce(0, +)

        return CoachContextTodayPacket(
            targets: CoachTodayTargetsContext(
                calorieTarget: nutrition.targets.calories,
                proteinTarget: nutrition.targets.protein,
                carbsTarget: nutrition.targets.carbs,
                fatTarget: nutrition.targets.fat,
                waterTargetMl: nutrition.water.targetMl
            ),
            nutrition: CoachTodayNutritionContext(
                caloriesConsumed: nutrition.totals.calories,
                caloriesRemaining: nutrition.remaining.calories,
                proteinConsumed: nutrition.totals.protein,
                proteinRemaining: nutrition.remaining.protein,
                carbsConsumed: nutrition.totals.carbs,
                carbsRemaining: nutrition.remaining.carbs,
                fatConsumed: nutrition.totals.fat,
                fatRemaining: nutrition.remaining.fat
            ),
            hydration: CoachTodayHydrationContext(
                waterConsumedMl: nutrition.water.consumedMl,
                waterRemainingMl: nutrition.water.remainingMl
            ),
            weight: weightKg.map { CoachTodayWeightContext(weightKg: $0) },
            steps: steps.value.map {
                CoachContextSourcedInt(
                    value: $0,
                    source: steps.source ?? "unknown",
                    asOf: steps.asOf,
                    confidence: steps.confidence
                )
            },
            workoutCaloriesBurned: workoutCalories > 0
                ? CoachContextSourcedInt(
                    value: workoutCalories,
                    source: workoutsResult.source,
                    asOf: dateProvider.now,
                    confidence: workoutsResult.isKnown ? .medium : .unknown
                )
                : nil
        )
    }

    private func makeTrainingContext(
        workoutsResult: WorkoutsReadResult,
        healthIntelligence: CoachHealthIntelligenceContext?,
        healthSnapshot: HealthIntelligenceSnapshot?,
        trainingLoad: TrainingLoadSummary?
    ) -> CoachTrainingContext? {
        var workoutSummaries = workoutsResult.workouts.map {
            CoachContextWorkoutSummary.from(
                record: $0,
                source: workoutsResult.source,
                confidence: workoutsResult.isKnown ? .medium : .unknown
            )
        }

        if workoutSummaries.isEmpty,
           let snapshotWorkout = healthSnapshot?.workout,
           let inferred = CoachContextWorkoutSummary.from(workout: snapshotWorkout, source: "healthIntelligence") {
            workoutSummaries = [inferred]
        }

        let workoutsToday = resolveWorkoutsToday(
            workoutsResult: workoutsResult,
            workoutSummaries: workoutSummaries,
            healthIntelligence: healthIntelligence
        )

        let load = trainingLoad ?? .unknown
        let hasTrainingSignals = workoutsToday != nil
            || !workoutSummaries.isEmpty
            || healthIntelligence != nil
            || load.status != .unknown

        guard hasTrainingSignals else { return nil }

        return CoachTrainingContext(
            workoutsToday: workoutsToday,
            workouts: workoutSummaries,
            trainingLoad: CoachHealthIntelligenceContextBuilder.trainingLoadStatusLabel(from: load),
            trainingLoadExplanation: CoachHealthIntelligenceContextBuilder.trainingLoadExplanation(from: load),
            trainingLoadConfidence: CoachHealthIntelligenceContextBuilder.trainingLoadConfidence(from: load),
            recoveryStatus: healthIntelligence?.recoveryStatus,
            readiness: healthIntelligence?.recoveryConfidence
        )
    }

    private func resolveWorkoutsToday(
        workoutsResult: WorkoutsReadResult,
        workoutSummaries: [CoachContextWorkoutSummary],
        healthIntelligence: CoachHealthIntelligenceContext?
    ) -> Int? {
        switch workoutsResult.availability {
        case .available:
            if !workoutsResult.workouts.isEmpty {
                return workoutsResult.workouts.count
            }
            if healthIntelligence?.workoutCompletedToday == true {
                return max(1, workoutSummaries.count)
            }
            return 0
        case .accessDenied, .unavailable:
            if !workoutSummaries.isEmpty {
                return workoutSummaries.count
            }
            if healthIntelligence?.workoutCompletedToday == true {
                return 1
            }
            return nil
        }
    }

    private struct ChatContextAssembly {
        var recentChatMessages: [CoachChatMessageContext]
        var currentUserMessage: String?
    }

    private func makeChatContext(
        from messages: [ChatMessage],
        currentUserMessage: String?,
        timelineEvents: [CoachTimelineEvent]
    ) -> ChatContextAssembly {
        let persisted = messages
            .suffix(Self.recentChatMessageLimit)
            .map { CoachChatMessageContext.from(message: $0) }

        guard let currentUserMessage else {
            return ChatContextAssembly(recentChatMessages: persisted, currentUserMessage: nil)
        }

        let trimmed = currentUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ChatContextAssembly(recentChatMessages: persisted, currentUserMessage: nil)
        }

        if let last = messages.last,
           last.role == .user,
           last.text.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed {
            return ChatContextAssembly(recentChatMessages: persisted, currentUserMessage: nil)
        }

        let timelineLinkedMessageIDs = Set(timelineEvents.compactMap(\.linkedMessageId))
        if let lastUserMessage = messages.last(where: { $0.role == .user }),
           timelineLinkedMessageIDs.contains(lastUserMessage.id),
           lastUserMessage.text.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed {
            return ChatContextAssembly(recentChatMessages: persisted, currentUserMessage: nil)
        }

        return ChatContextAssembly(recentChatMessages: persisted, currentUserMessage: trimmed)
    }

    private func makeMissingData(
        stepsResult: StepsReadResult,
        workoutsResult: WorkoutsReadResult,
        healthAccessDenied: Bool,
        healthUnavailable: Bool,
        healthIntelligenceTimedOut: Bool,
        healthIntelligenceFailed: Bool,
        healthIntelligence: CoachHealthIntelligenceContext?,
        healthSnapshot: HealthIntelligenceSnapshot?,
        recentMealCount: Int,
        weightEntries: [WeightEntry],
        dailyLog: DailyLog?,
        timelineEventCount: Int
    ) -> CoachMissingDataContext {
        let missingSignals = Set(healthIntelligence?.missingSignals.map { $0.lowercased() } ?? [])
        let recoverySignals = healthSnapshot?.recovery.missingSignals ?? []

        let workoutsDenied = workoutsResult.availability == .accessDenied
        let workoutsUnavailable = workoutsResult.availability == .unavailable
        let stepsDenied = stepsResult.accessDenied
        let stepsUnavailable = stepsResult.value == nil && (stepsResult.unavailable || healthActivityQuery == nil)

        return CoachMissingDataContext(
            stepsMissing: stepsResult.value == nil,
            workoutPermissionDeniedOrUnavailable: workoutsDenied || workoutsUnavailable || healthActivityQuery == nil,
            sleepMissing: missingSignals.contains(where: { $0.contains("sleep") })
                || recoverySignals.contains(.sleep),
            hrvMissing: missingSignals.contains(where: { $0.contains("hrv") })
                || recoverySignals.contains(.hrv),
            weightMissing: weightEntries.isEmpty && dailyLog?.weightKg == nil,
            noRecentMeals: recentMealCount == 0,
            noTimelineHistory: timelineEventCount == 0,
            healthKitDenied: healthAccessDenied || workoutsDenied || stepsDenied,
            healthKitUnavailable: healthUnavailable && !healthAccessDenied,
            stepsUnavailable: stepsUnavailable || stepsDenied,
            workoutsUnavailable: workoutsUnavailable || healthActivityQuery == nil,
            sleepUnavailable: missingSignals.contains(where: { $0.contains("sleep") })
                || recoverySignals.contains(.sleep),
            hrvUnavailable: missingSignals.contains(where: { $0.contains("hrv") })
                || recoverySignals.contains(.hrv),
            healthIntelligenceTimedOut: healthIntelligenceTimedOut,
            healthIntelligenceFailed: healthIntelligenceFailed
        )
    }

    private func makeAssumptions(
        stepsResult: StepsReadResult,
        workoutsResult: WorkoutsReadResult,
        timelineBackfillRan: Bool,
        healthIntelligenceTimedOut: Bool,
        healthIntelligenceFailed: Bool
    ) -> [CoachAssumptionContext] {
        var assumptions: [CoachAssumptionContext] = []

        assumptions.append(
            CoachAssumptionContext(
                key: "workout_calories_source",
                detail: "Workout calories are summed from Apple Health workout samples; legacy daily-log workout calories are excluded.",
                confidence: workoutsResult.workouts.isEmpty ? .unknown : .medium
            )
        )

        if stepsResult.value != nil {
            assumptions.append(
                CoachAssumptionContext(
                    key: "steps_source",
                    detail: "Steps are read from \(stepsResult.source ?? "health") when authorized.",
                    confidence: stepsResult.confidence
                )
            )
        }

        if timelineBackfillRan {
            assumptions.append(
                CoachAssumptionContext(
                    key: "timeline_backfill",
                    detail: "Timeline may include idempotent backfill events from persisted logs before live recorder events exist.",
                    confidence: .high
                )
            )
        }

        if healthIntelligenceTimedOut {
            assumptions.append(
                CoachAssumptionContext(
                    key: "health_intelligence_unavailable",
                    detail: "Health Intelligence was unavailable for this turn because snapshot composition timed out; rely on basic HealthKit steps and workouts only.",
                    confidence: .high
                )
            )
        } else if healthIntelligenceFailed {
            assumptions.append(
                CoachAssumptionContext(
                    key: "health_intelligence_unavailable",
                    detail: "Health Intelligence was unavailable for this turn because snapshot composition failed; rely on basic HealthKit steps and workouts only.",
                    confidence: .high
                )
            )
        }

        return assumptions
    }

    private func recordHealthTimelineEvents(
        workoutsResult: WorkoutsReadResult,
        stepsResult: StepsReadResult,
        healthIntelligence: CoachHealthIntelligenceContext?,
        healthAccessDenied: Bool,
        healthUnavailable: Bool,
        now: Date
    ) {
        guard let timelineRecorder else { return }

        if let steps = stepsResult.value {
            timelineRecorder.recordStepsUpdated(
                steps: steps,
                previousSteps: nil,
                occurredAt: now
            )
        }

        if workoutsResult.availability == .available, !workoutsResult.workouts.isEmpty {
            let totalDuration = workoutsResult.workouts.compactMap(\.durationMinutes).reduce(0, +)
            let totalCalories = workoutsResult.workouts.compactMap(\.activeCalories).reduce(0, +)
            timelineRecorder.recordWorkoutDetected(
                workoutCount: workoutsResult.workouts.count,
                totalDurationMinutes: totalDuration,
                totalActiveCalories: totalCalories > 0 ? totalCalories : nil,
                primaryWorkoutTitle: workoutsResult.workouts.first?.activityName,
                demand: healthIntelligence?.workoutDemand,
                occurredAt: now
            )
        }

        if healthAccessDenied {
            var missingSignals: [String] = []
            if workoutsResult.availability == .accessDenied {
                missingSignals.append("workouts")
            }
            if stepsResult.accessDenied {
                missingSignals.append("steps")
            }
            timelineRecorder.recordHealthDataUnavailable(
                missingSignals: missingSignals.isEmpty ? ["healthKit"] : missingSignals,
                reason: "access_denied",
                healthIntelligenceAwarenessAvailable: healthIntelligence != nil,
                occurredAt: now
            )
        } else if healthUnavailable {
            var missingSignals: [String] = []
            if workoutsResult.availability == .unavailable {
                missingSignals.append("workouts")
            }
            if stepsResult.unavailable, stepsResult.value == nil {
                missingSignals.append("steps")
            }
            timelineRecorder.recordHealthDataUnavailable(
                missingSignals: missingSignals.isEmpty ? ["healthKit"] : missingSignals,
                reason: "unavailable",
                healthIntelligenceAwarenessAvailable: healthIntelligence != nil,
                occurredAt: now
            )
        }
    }

    private func recordContextGenerated(
        packet: CoachContextPacketV2,
        mode: CoachContextGenerationMode,
        now: Date
    ) {
        timelineRecorder?.recordContextGenerated(
            payload: ContextGenerationPayload(
                lookbackDays: Self.crossDayLookbackDays,
                timelineEventCount: packet.timeline.recentEvents.count,
                recentMessageCount: packet.recentChatMessages.count,
                hasTodaySummary: packet.today != nil,
                hasHealthIntelligence: packet.healthIntelligence != nil,
                healthIntelligenceAwarenessAvailable: packet.healthIntelligence != nil,
                contextByteEstimate: packet.estimatedEncodedByteCount(),
                trigger: mode.rawValue
            ),
            occurredAt: now
        )
    }

    private func resolveGenerationMode(
        requested: CoachContextGenerationMode,
        readFailures: Int,
        healthAccessDenied: Bool,
        healthUnavailable: Bool,
        healthIntelligenceTimedOut: Bool,
        healthIntelligenceFailed: Bool,
        dailyLogServiceAvailable: Bool,
        dailyLogLoaded: Bool
    ) -> CoachContextGenerationMode {
        guard requested == .live else { return requested }

        if readFailures > 0
            || healthAccessDenied
            || healthUnavailable
            || healthIntelligenceTimedOut
            || healthIntelligenceFailed
            || (dailyLogServiceAvailable && !dailyLogLoaded) {
            return .degraded
        }
        return .live
    }

    private func logReadFailure(_ source: String, error: Error, readFailures: inout Int) {
        readFailures += 1
        logReadFailure(source, error: error)
    }

    private func logReadFailure(_ source: String, error: Error) {
        logger.debug("CoachContextPacketV2 \(source, privacy: .public) read failed: \(error.localizedDescription, privacy: .public)")
    }

    private static func goalType(for profile: UserProfile) -> String? {
        if let weeklyLoss = profile.targets.expectedWeeklyWeightLossKg {
            if weeklyLoss > 0.05 { return "Lose Fat" }
            if weeklyLoss < -0.05 { return "Gain Muscle" }
            return "Maintain"
        }
        switch profile.targets.aggressiveness {
        case .conservative, .moderate:
            return "Maintain"
        case .aggressive:
            return "Lose Fat"
        }
    }
}

// MARK: - Timeline selection

enum CoachContextPacketV2TimelineSelector {

    private static let photoEventTypes: Set<CoachTimelineEventType> = [
        .photoAttached,
        .photoAnalysisStarted,
        .photoAnalysisCompleted,
        .photoAnalysisFailed,
        .clarificationAsked,
        .clarificationAnswered
    ]

    private static let todayMutationTypes: Set<CoachTimelineEventType> = [
        .foodLogged,
        .waterLogged,
        .weightLogged
    ]

    private static let excludedContextTypes: Set<CoachTimelineEventType> = [
        .unknown,
        .foodEstimateCreated,
        .foodRejected,
        .pendingConfirmationRejected,
        .backendError,
        .authError,
        .systemRefresh,
        .contextGenerated,
        .healthDataUnavailable
    ]

    /// Whether an event may appear in AI context timeline (audit-only or speculative events excluded).
    static func isContextEligible(_ event: CoachTimelineEvent) -> Bool {
        if event.status == .superseded || event.status == .rejected || event.status == .failed {
            return false
        }
        if excludedContextTypes.contains(event.type) {
            return false
        }
        if event.status == .pending, event.type != .pendingConfirmationCreated {
            return false
        }
        return true
    }

    static func selectEvents(
        from events: [CoachTimelineEvent],
        todayLocalDate: String,
        limit: Int
    ) -> [CoachTimelineEvent] {
        let sorted = events
            .filter(isContextEligible)
            .sorted { $0.utcTimestamp > $1.utcTimestamp }

        var selected: [UUID: CoachTimelineEvent] = [:]

        func include(_ event: CoachTimelineEvent) {
            selected[event.id] = event
        }

        for event in sorted where event.localDate == todayLocalDate {
            if todayMutationTypes.contains(event.type), event.status == .confirmed {
                include(event)
            }
        }

        for event in sorted where event.localDate == todayLocalDate {
            if event.type == .pendingConfirmationCreated, event.status == .pending {
                include(event)
            }
        }

        for event in sorted where event.localDate == todayLocalDate && photoEventTypes.contains(event.type) {
            include(event)
        }

        if let workout = sorted.first(where: { $0.type == .workoutDetected }) {
            include(workout)
        }
        if let steps = sorted.first(where: { $0.type == .stepsUpdated }) {
            include(steps)
        }

        let todayCount = sorted.filter { $0.localDate == todayLocalDate }.count
        if todayCount < CoachContextPacketV2Builder.sparseTodayEventThreshold {
            for event in sorted where event.localDate != todayLocalDate {
                include(event)
                if selected.count >= limit { break }
            }
        }

        for event in sorted where isContextEligible(event) {
            include(event)
            if selected.count >= limit { break }
        }

        return selected.values.sorted { $0.utcTimestamp < $1.utcTimestamp }
    }

    static func makeContextEvents(
        from events: [CoachTimelineEvent],
        todayLocalDate: String,
        limit: Int
    ) -> [CoachTimelineContextEvent] {
        selectEvents(from: events, todayLocalDate: todayLocalDate, limit: limit).map { event in
            CoachTimelineContextEvent.from(
                event: event,
                summary: CoachTimelineEventSummaryBuilder.summary(for: event)
            )
        }
    }
}

// MARK: - Size compaction

enum CoachContextPacketV2SizeCompactor {

    static func compact(
        _ packet: CoachContextPacketV2,
        byteLimit: Int = CoachContextPacketV2Limits.defaultMaxEncodedBytes
    ) -> CoachContextPacketV2 {
        var result = packet.clampedForTransport()
        var bytes = result.estimatedEncodedByteCount()
        guard bytes > byteLimit else { return result }

        result.recentChatMessages = result.recentChatMessages.map { message in
            guard message.role == ChatMessageRole.assistant.rawValue else { return message }
            var compact = message
            compact.text = truncate(message.text, maxLength: 80)
            return compact
        }
        bytes = result.estimatedEncodedByteCount()
        guard bytes > byteLimit else { return result }

        let protectedIDs = protectedTimelineEventIDs(in: result)
        var events = result.timeline.recentEvents
        while bytes > byteLimit {
            guard let removalIndex = events.firstIndex(where: { event in
                !protectedIDs.contains(event.id) && isLowValueSystemEvent(event)
            }) else {
                break
            }
            events.remove(at: removalIndex)
            result.timeline.recentEvents = events
            bytes = result.estimatedEncodedByteCount()
        }

        if bytes > byteLimit {
            events = events.map { event in
                guard event.type == CoachTimelineEventType.assistantMessage.rawValue else { return event }
                var compact = event
                compact.summary = truncate(event.summary, maxLength: 60)
                compact.compactPayload = nil
                return compact
            }
            result.timeline.recentEvents = events
        }

        return result.clampedForTransport()
    }

    private static func protectedTimelineEventIDs(in packet: CoachContextPacketV2) -> Set<UUID> {
        let today = packet.meta.localDate
        let protectedTypes: Set<String> = [
            CoachTimelineEventType.foodLogged.rawValue,
            CoachTimelineEventType.waterLogged.rawValue,
            CoachTimelineEventType.weightLogged.rawValue,
            CoachTimelineEventType.pendingConfirmationCreated.rawValue,
            CoachTimelineEventType.photoAttached.rawValue,
            CoachTimelineEventType.photoAnalysisStarted.rawValue,
            CoachTimelineEventType.photoAnalysisCompleted.rawValue,
            CoachTimelineEventType.photoAnalysisFailed.rawValue,
            CoachTimelineEventType.workoutDetected.rawValue,
            CoachTimelineEventType.stepsUpdated.rawValue
        ]

        return Set(
            packet.timeline.recentEvents.compactMap { event in
                guard protectedTypes.contains(event.type) else { return nil }
                if [
                    CoachTimelineEventType.foodLogged.rawValue,
                    CoachTimelineEventType.waterLogged.rawValue,
                    CoachTimelineEventType.weightLogged.rawValue
                ].contains(event.type) {
                    return event.timestampLocalDateOrMeta(today) == today ? event.id : nil
                }
                return event.id
            }
        )
    }

    private static func isLowValueSystemEvent(_ event: CoachTimelineContextEvent) -> Bool {
        switch event.type {
        case CoachTimelineEventType.systemRefresh.rawValue,
             CoachTimelineEventType.contextGenerated.rawValue,
             CoachTimelineEventType.healthDataUnavailable.rawValue,
             CoachTimelineEventType.stepsUpdated.rawValue:
            return true
        default:
            return event.source == CoachTimelineEventSourceAttribution.system.rawValue
                && event.type != CoachTimelineEventType.foodLogged.rawValue
        }
    }

    private static func truncate(_ value: String, maxLength: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<index]) + "…"
    }
}

private extension CoachTimelineContextEvent {

    func timestampLocalDateOrMeta(_ fallbackToday: String) -> String {
        let timestamps = CoachTimelineEvent.makeTimestamps(from: timestamp)
        return timestamps.localDate.isEmpty ? fallbackToday : timestamps.localDate
    }
}