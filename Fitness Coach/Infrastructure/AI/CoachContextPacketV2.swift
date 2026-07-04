//
//  CoachContextPacketV2.swift
//  Fitness Coach
//
//  Forma — Structured Coach AI context packet (v2 contract).
//
//  Transport-shaped Codable types for the FitPilot AI gateway. No HealthKit,
//  SwiftData, or UI types. Coach AI transport uses CoachContextPacketV2 exclusively.
//

import Foundation

// MARK: - Root packet

/// Structured Coach context sent to every Coach AI gateway endpoint.
struct CoachContextPacketV2: Codable, Equatable, Sendable {

    static let schemaVersion = 2

    var meta: CoachContextMeta
    var profile: CoachUserProfileContext?
    var today: CoachContextTodayPacket?
    var training: CoachTrainingContext?
    var healthIntelligence: CoachHealthIntelligenceContext?
    var timeline: CoachContextTimelinePacket
    var recentChatMessages: [CoachChatMessageContext]
    /// Transient in-flight user text for the active turn (not duplicated in `recentChatMessages`).
    var currentUserMessage: String?
    var recentMealsStructured: [CoachRecentMealContext]
    var commonFoods: [CoachCommonFoodContext]
    var missingData: CoachMissingDataContext
    var assumptions: [CoachAssumptionContext]
    var generationMode: CoachContextGenerationMode
    var sourceAttribution: CoachContextSourceAttribution?

    init(
        meta: CoachContextMeta,
        profile: CoachUserProfileContext? = nil,
        today: CoachContextTodayPacket? = nil,
        training: CoachTrainingContext? = nil,
        healthIntelligence: CoachHealthIntelligenceContext? = nil,
        timeline: CoachContextTimelinePacket = CoachContextTimelinePacket(),
        recentChatMessages: [CoachChatMessageContext] = [],
        currentUserMessage: String? = nil,
        recentMealsStructured: [CoachRecentMealContext] = [],
        commonFoods: [CoachCommonFoodContext] = [],
        missingData: CoachMissingDataContext = CoachMissingDataContext(),
        assumptions: [CoachAssumptionContext] = [],
        generationMode: CoachContextGenerationMode = .live,
        sourceAttribution: CoachContextSourceAttribution? = nil
    ) {
        self.meta = meta
        self.profile = profile
        self.today = today
        self.training = training
        self.healthIntelligence = healthIntelligence
        self.timeline = timeline
        self.recentChatMessages = recentChatMessages
        self.currentUserMessage = currentUserMessage
        self.recentMealsStructured = recentMealsStructured
        self.commonFoods = commonFoods
        self.missingData = missingData
        self.assumptions = assumptions
        self.generationMode = generationMode
        self.sourceAttribution = sourceAttribution
    }
}

// MARK: - Meta

struct CoachContextMeta: Codable, Equatable, Sendable {

    var generatedAt: Date
    var timezoneIdentifier: String
    var localDate: String
    var localTime: String
    var appVersion: String?
    var schemaVersion: Int

    init(
        generatedAt: Date,
        timezoneIdentifier: String,
        localDate: String,
        localTime: String,
        appVersion: String? = CoachContextMeta.currentAppVersion,
        schemaVersion: Int = CoachContextPacketV2.schemaVersion
    ) {
        self.generatedAt = generatedAt
        self.timezoneIdentifier = timezoneIdentifier
        self.localDate = localDate
        self.localTime = localTime
        self.appVersion = appVersion
        self.schemaVersion = schemaVersion
    }

    static var currentAppVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    static func make(
        generatedAt: Date = Date(),
        calendar: Calendar = .current
    ) -> CoachContextMeta {
        let timezone = calendar.timeZone
        let timestamps = CoachTimelineEvent.makeTimestamps(from: generatedAt, calendar: calendar)

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.timeZone = timezone
        timeFormatter.dateFormat = "HH:mm"

        return CoachContextMeta(
            generatedAt: generatedAt,
            timezoneIdentifier: timezone.identifier,
            localDate: timestamps.localDate,
            localTime: timeFormatter.string(from: generatedAt)
        )
    }
}

// MARK: - Profile

struct CoachUserProfileContext: Codable, Equatable, Sendable {
    var age: Int?
    var sex: Sex?
    var heightCm: Double?
    var currentWeightKg: Double?
    var goalWeightKg: Double?
    var activityLevel: ActivityLevel?
    var trainingFrequencyPerWeek: Int?
    var goalType: String?
}

// MARK: - Today sections

struct CoachContextTodayPacket: Codable, Equatable, Sendable {
    var targets: CoachTodayTargetsContext?
    var nutrition: CoachTodayNutritionContext?
    var hydration: CoachTodayHydrationContext?
    var weight: CoachTodayWeightContext?
    var steps: CoachContextSourcedInt?
    var workoutCaloriesBurned: CoachContextSourcedInt?
}

struct CoachTodayTargetsContext: Codable, Equatable, Sendable {
    var calorieTarget: Int?
    var proteinTarget: Double?
    var carbsTarget: Double?
    var fatTarget: Double?
    var waterTargetMl: Int?
}

struct CoachTodayNutritionContext: Codable, Equatable, Sendable {
    var caloriesConsumed: Int?
    var caloriesRemaining: Int?
    var proteinConsumed: Double?
    var proteinRemaining: Double?
    var carbsConsumed: Double?
    var carbsRemaining: Double?
    var fatConsumed: Double?
    var fatRemaining: Double?
    var caloriesOverTarget: Bool?
    var proteinOverTarget: Bool?
    var carbsOverTarget: Bool?
    var fatOverTarget: Bool?
}

struct CoachTodayHydrationContext: Codable, Equatable, Sendable {
    var waterConsumedMl: Int?
    var waterRemainingMl: Int?
    var waterOverTarget: Bool?
}

struct CoachTodayWeightContext: Codable, Equatable, Sendable {
    var weightKg: Double?
}

/// Integer metric with provenance — used for steps and workout calorie rollups.
struct CoachContextSourcedInt: Codable, Equatable, Sendable {
    var value: Int
    var source: String
    var asOf: Date?
    var confidence: CoachContextConfidence?
}

// MARK: - Training

struct CoachTrainingContext: Codable, Equatable, Sendable {
    var workoutsToday: Int?
    var workouts: [CoachContextWorkoutSummary]
    var trainingLoad: String?
    var trainingLoadExplanation: String?
    var trainingLoadConfidence: CoachContextConfidence?
    var recoveryStatus: String?
    var readiness: String?

    init(
        workoutsToday: Int? = nil,
        workouts: [CoachContextWorkoutSummary] = [],
        trainingLoad: String? = nil,
        trainingLoadExplanation: String? = nil,
        trainingLoadConfidence: CoachContextConfidence? = nil,
        recoveryStatus: String? = nil,
        readiness: String? = nil
    ) {
        self.workoutsToday = workoutsToday
        self.workouts = workouts
        self.trainingLoad = trainingLoad
        self.trainingLoadExplanation = trainingLoadExplanation
        self.trainingLoadConfidence = trainingLoadConfidence
        self.recoveryStatus = recoveryStatus
        self.readiness = readiness
    }
}

struct CoachContextWorkoutSummary: Codable, Equatable, Sendable {
    var title: String
    var type: String?
    var start: Date
    var end: Date
    var durationMinutes: Int?
    var activeEnergyKcal: Int?
    var source: String?
    var confidence: CoachContextConfidence?
}

// MARK: - Timeline

struct CoachContextTimelinePacket: Codable, Equatable, Sendable {
    var recentEvents: [CoachTimelineContextEvent]

    init(recentEvents: [CoachTimelineContextEvent] = []) {
        self.recentEvents = recentEvents
    }
}

struct CoachChatMessageContext: Codable, Equatable, Sendable {
    var id: UUID
    var role: String
    var text: String
    var timestamp: Date
    var hasPhotoAttachment: Bool
}

struct CoachTimelineContextEvent: Codable, Equatable, Sendable {
    var id: UUID
    var timestamp: Date
    var type: String
    var source: String
    var status: String
    var summary: String
    var compactPayload: [String: String]?
    var confidence: CoachContextConfidence?
    var linkedEntryId: UUID?
    var linkedMessageId: UUID?
}

// MARK: - Meals & foods

struct CoachRecentMealContext: Codable, Equatable, Sendable {
    var name: String
    var quantity: Double?
    var unit: String?
    var calories: Int?
    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?
    var loggedAt: Date?
    var localDate: String?
    var source: String?
    var confidence: CoachContextConfidence?
    var linkedEntryId: UUID?
}

struct CoachCommonFoodContext: Codable, Equatable, Sendable {
    var name: String
    var displayName: String?
    var frequency: Int?
    var logCount: Int?
    var lastLoggedAt: Date?
    var typicalCalories: Int?
    var typicalProteinGrams: Double?
    var typicalCarbsGrams: Double?
    var typicalFatGrams: Double?
    var macroConfidence: CoachContextConfidence?
}

// MARK: - Missing data & assumptions

struct CoachMissingDataContext: Codable, Equatable, Sendable {
    var stepsMissing: Bool
    var workoutPermissionDeniedOrUnavailable: Bool
    var sleepMissing: Bool
    var hrvMissing: Bool
    var weightMissing: Bool
    var noRecentMeals: Bool
    var noTimelineHistory: Bool
    var healthKitDenied: Bool
    var healthKitUnavailable: Bool
    var stepsUnavailable: Bool
    var workoutsUnavailable: Bool
    var sleepUnavailable: Bool
    var hrvUnavailable: Bool

    init(
        stepsMissing: Bool = false,
        workoutPermissionDeniedOrUnavailable: Bool = false,
        sleepMissing: Bool = false,
        hrvMissing: Bool = false,
        weightMissing: Bool = false,
        noRecentMeals: Bool = false,
        noTimelineHistory: Bool = false,
        healthKitDenied: Bool = false,
        healthKitUnavailable: Bool = false,
        stepsUnavailable: Bool = false,
        workoutsUnavailable: Bool = false,
        sleepUnavailable: Bool = false,
        hrvUnavailable: Bool = false
    ) {
        self.stepsMissing = stepsMissing
        self.workoutPermissionDeniedOrUnavailable = workoutPermissionDeniedOrUnavailable
        self.sleepMissing = sleepMissing
        self.hrvMissing = hrvMissing
        self.weightMissing = weightMissing
        self.noRecentMeals = noRecentMeals
        self.noTimelineHistory = noTimelineHistory
        self.healthKitDenied = healthKitDenied
        self.healthKitUnavailable = healthKitUnavailable
        self.stepsUnavailable = stepsUnavailable
        self.workoutsUnavailable = workoutsUnavailable
        self.sleepUnavailable = sleepUnavailable
        self.hrvUnavailable = hrvUnavailable
    }

    var hasAnyMissingSignals: Bool {
        stepsMissing
            || workoutPermissionDeniedOrUnavailable
            || sleepMissing
            || hrvMissing
            || weightMissing
            || noRecentMeals
            || noTimelineHistory
            || healthKitDenied
            || healthKitUnavailable
            || stepsUnavailable
            || workoutsUnavailable
            || sleepUnavailable
            || hrvUnavailable
    }
}

struct CoachAssumptionContext: Codable, Equatable, Sendable {
    var key: String
    var detail: String
    var confidence: CoachContextConfidence?
}

// MARK: - Attribution & confidence

struct CoachContextSourceAttribution: Codable, Equatable, Sendable {
    var generationMode: CoachContextGenerationMode
    var timelineEventCount: Int?
    var recentMealCount: Int?
    var commonFoodCount: Int?
    var healthIntelligenceIncluded: Bool
    var sources: [String]

    init(
        generationMode: CoachContextGenerationMode,
        timelineEventCount: Int? = nil,
        recentMealCount: Int? = nil,
        commonFoodCount: Int? = nil,
        healthIntelligenceIncluded: Bool = false,
        sources: [String] = []
    ) {
        self.generationMode = generationMode
        self.timelineEventCount = timelineEventCount
        self.recentMealCount = recentMealCount
        self.commonFoodCount = commonFoodCount
        self.healthIntelligenceIncluded = healthIntelligenceIncluded
        self.sources = sources
    }
}

enum CoachContextConfidence: String, Codable, CaseIterable, Equatable, Sendable {
    case high
    case medium
    case low
    case unknown
}

enum CoachContextGenerationMode: String, Codable, CaseIterable, Equatable, Sendable {
    case live
    case backfill
    case preview
    case degraded
}

// MARK: - Payload limits

enum CoachContextPacketV2Limits {

    /// Default encoded JSON ceiling for outbound Coach context packets.
    static let defaultMaxEncodedBytes = 24_576

    static let maxTimelineEvents = 40
    static let maxChatMessages = 12
    static let maxChatTextLength = 180
    static let maxRecentMeals = 10
    static let maxCommonFoods = 10
    static let maxAssumptions = 8
    static let maxSummaryLength = 180
    static let maxCompactPayloadEntries = 6

    static func fitsEncodedByteCount(_ byteCount: Int, limit: Int = defaultMaxEncodedBytes) -> Bool {
        byteCount <= limit
    }
}

// MARK: - Encoding helpers

extension CoachContextPacketV2 {

    static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = []
        return encoder
    }

    static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func encodedJSONData(encoder: JSONEncoder = makeJSONEncoder()) throws -> Data {
        try encoder.encode(clampedForTransport())
    }

    func estimatedEncodedByteCount(encoder: JSONEncoder = makeJSONEncoder()) -> Int {
        (try? encodedJSONData(encoder: encoder).count) ?? 0
    }

    func fitsWithinByteLimit(_ limit: Int = CoachContextPacketV2Limits.defaultMaxEncodedBytes) -> Bool {
        CoachContextPacketV2Limits.fitsEncodedByteCount(estimatedEncodedByteCount(), limit: limit)
    }

    /// Returns a transport-safe copy with list and string fields clamped to contract limits.
    func clampedForTransport() -> CoachContextPacketV2 {
        var copy = self

        copy.timeline.recentEvents = Array(
            timeline.recentEvents
                .prefix(CoachContextPacketV2Limits.maxTimelineEvents)
                .map { $0.clampedForTransport() }
        )
        copy.recentChatMessages = Array(
            recentChatMessages.prefix(CoachContextPacketV2Limits.maxChatMessages)
        )
        copy.recentMealsStructured = Array(
            recentMealsStructured.prefix(CoachContextPacketV2Limits.maxRecentMeals)
        )
        copy.commonFoods = Array(
            commonFoods.prefix(CoachContextPacketV2Limits.maxCommonFoods)
        )
        copy.assumptions = Array(
            assumptions.prefix(CoachContextPacketV2Limits.maxAssumptions)
        )

        return copy
    }

    /// Privacy-safe single-line summary for logs and debug overlays.
    func redactedDebugDescription(maxLength: Int = 500) -> String {
        var parts: [String] = [
            "CoachContextPacketV2",
            "schema=\(meta.schemaVersion)",
            "date=\(meta.localDate)",
            "mode=\(generationMode.rawValue)",
            "profile=\(profile != nil)",
            "today=\(today != nil)",
            "trainingWorkouts=\(training?.workoutsToday ?? 0)",
            "timelineEvents=\(timeline.recentEvents.count)",
            "chatMessages=\(recentChatMessages.count)",
            "meals=\(recentMealsStructured.count)",
            "commonFoods=\(commonFoods.count)",
            "missing=\(missingData.missingSignalLabels.joined(separator: ","))",
            "bytes~\(estimatedEncodedByteCount())"
        ]

        if let attribution = sourceAttribution, !attribution.sources.isEmpty {
            parts.append("sources=\(attribution.sources.joined(separator: "|"))")
        }

        let line = parts.joined(separator: " · ")
        guard line.count > maxLength else { return line }
        let index = line.index(line.startIndex, offsetBy: maxLength)
        return String(line[..<index]) + "…"
    }
}

extension CoachTimelineContextEvent {

    func clampedForTransport() -> CoachTimelineContextEvent {
        var copy = self
        copy.summary = Self.clamp(copy.summary, maxLength: CoachContextPacketV2Limits.maxSummaryLength)
        if let payload = compactPayload {
            copy.compactPayload = Dictionary(
                uniqueKeysWithValues: payload
                    .prefix(CoachContextPacketV2Limits.maxCompactPayloadEntries)
                    .map { (Self.clamp($0.key, maxLength: 40), Self.clamp($0.value, maxLength: 80)) }
            )
        }
        return copy
    }

    private static func clamp(_ value: String, maxLength: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<index]) + "…"
    }
}

extension CoachMissingDataContext {

    var missingSignalLabels: [String] {
        var labels: [String] = []
        if stepsMissing || stepsUnavailable { labels.append("steps") }
        if workoutPermissionDeniedOrUnavailable || workoutsUnavailable { labels.append("workouts") }
        if sleepMissing || sleepUnavailable { labels.append("sleep") }
        if hrvMissing || hrvUnavailable { labels.append("hrv") }
        if healthKitDenied { labels.append("healthKitDenied") }
        if healthKitUnavailable { labels.append("healthKitUnavailable") }
        if weightMissing { labels.append("weight") }
        if noRecentMeals { labels.append("meals") }
        if noTimelineHistory { labels.append("timeline") }
        return labels
    }
}

// MARK: - Domain bridges

extension CoachContextConfidence {

    static func from(_ level: ConfidenceLevel) -> CoachContextConfidence {
        switch level {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }

    static func from(_ level: CoachTimelineEventConfidence) -> CoachContextConfidence {
        switch level {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        case .unknown: return .unknown
        }
    }

    static func from(_ level: AIConfidence) -> CoachContextConfidence {
        switch level {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }
}

extension CoachTimelineContextEvent {

    static func from(event: CoachTimelineEvent, summary: String) -> CoachTimelineContextEvent {
        CoachTimelineContextEvent(
            id: event.id,
            timestamp: event.utcTimestamp,
            type: event.type.rawValue,
            source: event.sourceAttribution.rawValue,
            status: event.status.rawValue,
            summary: summary,
            compactPayload: Self.compactPayload(from: event.payload),
            confidence: event.confidence.map(CoachContextConfidence.from),
            linkedEntryId: event.linkedEntryId,
            linkedMessageId: event.linkedMessageId
        )
    }

    private static func compactPayload(from payload: CoachTimelineEventPayload) -> [String: String]? {
        switch payload {
        case .message(let value):
            return ["preview": value.textPreview]
        case .foodEstimate(let value):
            return ["meal": value.mealName]
        case .foodLogged(let value):
            return ["name": value.name, "kcal": String(value.calories)]
        case .waterLogged(let value):
            return ["ml": String(value.amountMl)]
        case .weightLogged(let value):
            return ["kg": String(value.weightKg)]
        case .workoutDetected(let value):
            return ["count": String(value.workoutCount)]
        case .steps(let value):
            return ["steps": String(value.steps)]
        case .photo:
            return ["kind": "photo"]
        case .confirmation(let value):
            return ["kind": value.kind]
        case .error(let value):
            return ["category": value.category]
        case .healthAvailability(let value):
            return ["available": value.isAvailable ? "true" : "false"]
        case .contextGeneration(let value):
            if let days = value.lookbackDays {
                return ["lookbackDays": String(days)]
            }
            return nil
        case .undo(let value):
            return ["entryType": value.entryType]
        case .systemRefresh(let value):
            if let reason = value.reason { return ["reason": reason] }
            return nil
        case .empty:
            return nil
        }
    }
}

extension CoachChatMessageContext {

    static func from(
        message: ChatMessage,
        maxTextLength: Int = CoachContextPacketV2Limits.maxChatTextLength
    ) -> CoachChatMessageContext {
        let text = CoachChatMessageContext.clamp(message.text, maxLength: maxTextLength)
        return CoachChatMessageContext(
            id: message.id,
            role: message.role.rawValue,
            text: text,
            timestamp: message.createdAt,
            hasPhotoAttachment: message.hasMealPhotoAttachment
        )
    }

    private static func clamp(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<index]) + "…"
    }
}

extension CoachRecentMealContext {

    static func from(
        entry: FoodEntry,
        calendar: Calendar = .current
    ) -> CoachRecentMealContext {
        let timestamps = CoachTimelineEvent.makeTimestamps(from: entry.createdAt, calendar: calendar)
        return CoachRecentMealContext(
            name: entry.name,
            quantity: entry.quantity,
            unit: entry.unit,
            calories: entry.calories,
            proteinGrams: roundedMacro(entry.protein),
            carbsGrams: roundedMacro(entry.carbs),
            fatGrams: roundedMacro(entry.fat),
            loggedAt: entry.createdAt,
            localDate: timestamps.localDate,
            source: entry.source.rawValue,
            confidence: CoachContextConfidence.from(entry.confidence),
            linkedEntryId: entry.id
        )
    }

    private static func roundedMacro(_ value: Double) -> Double {
        guard value > 0 else { return value }
        let rounded = (value * 10).rounded() / 10
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? value.rounded()
            : rounded
    }
}

extension CoachCommonFoodContext {

    init(
        normalizedName: String,
        displayName: String,
        frequency: Int,
        lastLoggedAt: Date,
        typicalCalories: Int?,
        typicalProteinGrams: Double?,
        typicalCarbsGrams: Double?,
        typicalFatGrams: Double?,
        macroConfidence: CoachContextConfidence?
    ) {
        self.name = normalizedName
        self.displayName = displayName
        self.frequency = frequency
        self.logCount = frequency
        self.lastLoggedAt = lastLoggedAt
        self.typicalCalories = typicalCalories
        self.typicalProteinGrams = typicalProteinGrams
        self.typicalCarbsGrams = typicalCarbsGrams
        self.typicalFatGrams = typicalFatGrams
        self.macroConfidence = macroConfidence
    }
}

extension CoachContextWorkoutSummary {

    static func from(
        record: HealthWorkoutRecord,
        source: String = "healthKit",
        confidence: CoachContextConfidence = .medium
    ) -> CoachContextWorkoutSummary {
        CoachContextWorkoutSummary(
            title: record.activityName,
            type: record.activityName,
            start: record.startDate,
            end: record.endDate,
            durationMinutes: record.durationMinutes,
            activeEnergyKcal: record.activeCalories,
            source: source,
            confidence: confidence
        )
    }

    static func from(
        workout: WorkoutSummary,
        source: String = "healthIntelligence"
    ) -> CoachContextWorkoutSummary? {
        guard workout.hasWorkout else { return nil }
        guard let start = workout.latestWorkoutStart, let end = workout.latestWorkoutEnd else {
            return nil
        }

        let confidence: CoachContextConfidence = {
            switch workout.confidence {
            case .high: return .high
            case .moderate: return .medium
            case .low: return .low
            }
        }()

        return CoachContextWorkoutSummary(
            title: workout.title,
            type: workout.primaryWorkoutType?.rawValue ?? workout.title,
            start: start,
            end: end,
            durationMinutes: workout.totalDurationMinutes,
            activeEnergyKcal: workout.totalActiveCalories,
            source: source,
            confidence: confidence
        )
    }
}
