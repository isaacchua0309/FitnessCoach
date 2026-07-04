//
//  CoachContextPacketV2FallbackBuilder.swift
//  Fitness Coach
//
//  Forma — Minimal safe CoachContextPacketV2 when full assembly fails.
//

import Foundation
import OSLog

enum CoachContextBuildError: Error, Equatable {

    case dailyLogFailed
    case foodLogFailed
    case timelineFailed
    case healthQueryFailed
    case assemblyFailed

    var redactedDescription: String {
        switch self {
        case .dailyLogFailed: return "dailyLog"
        case .foodLogFailed: return "foodLog"
        case .timelineFailed: return "timeline"
        case .healthQueryFailed: return "healthQuery"
        case .assemblyFailed: return "assembly"
        }
    }

    static func classify(_ error: Error) -> CoachContextBuildError {
        if let buildError = error as? CoachContextBuildError {
            return buildError
        }
        return .assemblyFailed
    }

    var shouldSkipTimelineRecording: Bool {
        switch self {
        case .timelineFailed:
            return true
        case .dailyLogFailed, .foodLogFailed, .healthQueryFailed, .assemblyFailed:
            return false
        }
    }
}

enum CoachContextPacketV2FallbackBuilder {

    private static let logger = Logger(subsystem: "Forma", category: "CoachContextPacketV2")

    static func build(
        failure: Error,
        now: Date,
        calendar: Calendar,
        recentMessages: [ChatMessage],
        currentUserMessage: String?,
        userProfileService: (any UserProfileReading)?,
        dailyLogService: (any DailyLogReading)?
    ) -> CoachContextPacketV2 {
        let buildError = CoachContextBuildError.classify(failure)
        let profile = makeProfileContext(from: userProfileService)
        let today = makeMinimalToday(from: dailyLogService)
        let chatContext = makeChatContext(
            from: recentMessages,
            currentUserMessage: currentUserMessage
        )

        let assumptions: [CoachAssumptionContext] = [
            CoachAssumptionContext(
                key: "contextGeneration",
                detail: "Full context assembly failed (\(buildError.redactedDescription)); using minimal safe context only.",
                confidence: .high
            ),
            CoachAssumptionContext(
                key: "degradedMode",
                detail: "Steps, workouts, meals, timeline history, and pending facts were omitted to avoid stale or incomplete data.",
                confidence: .high
            )
        ]

        let missingData = CoachMissingDataContext(
            stepsMissing: true,
            workoutPermissionDeniedOrUnavailable: true,
            sleepMissing: true,
            hrvMissing: true,
            weightMissing: today?.weight?.weightKg == nil,
            noRecentMeals: true,
            noTimelineHistory: true,
            healthKitUnavailable: true,
            stepsUnavailable: true,
            workoutsUnavailable: true,
            sleepUnavailable: true,
            hrvUnavailable: true,
            contextGenerationFailed: true
        )

        var sources: [String] = ["fallback"]
        if profile != nil { sources.append("profile") }
        if today != nil { sources.append("dailyLog") }

        let packet = CoachContextPacketV2(
            meta: CoachContextMeta.make(generatedAt: now, calendar: calendar),
            profile: profile,
            today: today,
            training: nil,
            healthIntelligence: nil,
            timeline: CoachContextTimelinePacket(recentEvents: []),
            recentChatMessages: chatContext.recentChatMessages,
            currentUserMessage: chatContext.currentUserMessage,
            recentMealsStructured: [],
            commonFoods: [],
            foodCorrectionMemory: [],
            missingData: missingData,
            assumptions: assumptions,
            generationMode: .degraded,
            sourceAttribution: CoachContextSourceAttribution(
                generationMode: .degraded,
                timelineEventCount: 0,
                recentMealCount: 0,
                commonFoodCount: 0,
                healthIntelligenceIncluded: false,
                sources: sources.sorted()
            )
        )

        logFallbackEngaged(buildError: buildError, packet: packet, underlying: failure)
        return packet
    }

    static func logFallbackEngaged(
        buildError: CoachContextBuildError,
        packet: CoachContextPacketV2,
        underlying: Error
    ) {
        logger.warning(
            "CoachContextPacketV2 fallback engaged reason=\(buildError.redactedDescription, privacy: .public) packet=\(packet.redactedDebugDescription(), privacy: .public) error=\(redactedFailureDescription(underlying), privacy: .public)"
        )
        FormaPipelineTracer.event(
            stage: .context,
            level: .warn,
            message: "CoachContextPacketV2 fallback engaged",
            fields: [
                "reason": buildError.redactedDescription,
                "mode": CoachContextGenerationMode.degraded.rawValue,
                "contextGenerationFailed": "true",
                "packet": packet.redactedDebugDescription()
            ]
        )
    }

    static func redactedFailureDescription(_ error: Error) -> String {
        let buildError = CoachContextBuildError.classify(error)
        return buildError.redactedDescription
    }

    private static func makeProfileContext(
        from userProfileService: (any UserProfileReading)?
    ) -> CoachUserProfileContext? {
        guard let profile = try? userProfileService?.getCurrentProfile() else { return nil }
        return CoachUserProfileContext(
            age: profile.age,
            sex: profile.sex,
            heightCm: profile.heightCm,
            currentWeightKg: profile.currentWeightKg,
            goalWeightKg: profile.goalWeightKg,
            activityLevel: profile.activityLevel,
            trainingFrequencyPerWeek: profile.trainingFrequencyPerWeek,
            goalType: CoachContextPacketV2Builder.goalType(for: profile)
        )
    }

    private static func makeMinimalToday(
        from dailyLogService: (any DailyLogReading)?
    ) -> CoachContextTodayPacket? {
        guard let dailyLog = try? dailyLogService?.getTodayLog() else { return nil }

        let nutrition = DailyNutritionSummaryBuilder.build(from: dailyLog)
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
            weight: dailyLog.weightKg.map { CoachTodayWeightContext(weightKg: $0) },
            steps: nil,
            workoutCaloriesBurned: nil
        )
    }

    private struct ChatContextAssembly {
        var recentChatMessages: [CoachChatMessageContext]
        var currentUserMessage: String?
    }

    private static func makeChatContext(
        from messages: [ChatMessage],
        currentUserMessage: String?
    ) -> ChatContextAssembly {
        let persisted = messages
            .suffix(CoachContextPacketV2Builder.recentChatMessageLimit)
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

        return ChatContextAssembly(recentChatMessages: persisted, currentUserMessage: trimmed)
    }
}
