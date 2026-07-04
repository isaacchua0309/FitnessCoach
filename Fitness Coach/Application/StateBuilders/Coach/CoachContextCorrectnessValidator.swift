//
//  CoachContextCorrectnessValidator.swift
//  Fitness Coach
//
//  Validates CoachContextPacketV2 internal consistency before backend transport.
//

import Foundation
import OSLog

enum CoachContextValidationRule: String, Codable, Equatable, Sendable, CaseIterable {
    case caloriesMatchConfirmedFood
    case macrosMatchConfirmedFood
    case macrosNonNegative
    case waterNonNegative
    case remainingValuesConsistent
    case overTargetFlagsConsistent
    case pendingRejectedNotInTotals
    case assistantTextNotInStructuredFacts
    case timelineSorted
    case localDateTimezoneConsistent
    case timelineEventLocalDateConsistent
    case stepsSourceExplicit
    case workoutSourceExplicit
    case recentMealsSourceAttribution
    case healthStepsNotSilentlyZero
    case healthWorkoutsNotSilentlyZero
    case missingDataPopulated
    case rejectedEventsExcludedFromTimeline
    case editDeleteTimelineConsistency
    case corruptedTimelinePayload
    case privacySensitiveContent
    case contextSizeBelowThreshold
}

struct CoachContextValidationIssue: Equatable, Sendable {
    var rule: CoachContextValidationRule
    var message: String
}

struct CoachContextValidationResult: Equatable, Sendable {
    var issues: [CoachContextValidationIssue]
    var correctedPacket: CoachContextPacketV2

    var isValid: Bool { issues.isEmpty }
}

enum CoachContextCorrectnessValidator {

    private static let logger = Logger(
        subsystem: "Forma",
        category: "CoachContextCorrectnessValidator"
    )

    private static let calorieTolerance = 5
    private static let macroTolerance = 1.0

    private static let speculativeTimelineTypes: Set<String> = [
        CoachTimelineEventType.foodEstimateCreated.rawValue,
        CoachTimelineEventType.foodRejected.rawValue,
        CoachTimelineEventType.pendingConfirmationCreated.rawValue,
        CoachTimelineEventType.pendingConfirmationRejected.rawValue,
    ]

    private static let excludedTimelineTypes: Set<String> = [
        CoachTimelineEventType.unknown.rawValue,
        CoachTimelineEventType.foodEstimateCreated.rawValue,
        CoachTimelineEventType.foodRejected.rawValue,
        CoachTimelineEventType.pendingConfirmationRejected.rawValue,
        CoachTimelineEventType.pendingConfirmationConfirmed.rawValue,
        CoachTimelineEventType.backendError.rawValue,
        CoachTimelineEventType.authError.rawValue,
        CoachTimelineEventType.systemRefresh.rawValue,
        CoachTimelineEventType.contextGenerated.rawValue,
        CoachTimelineEventType.healthDataUnavailable.rawValue,
    ]

    private static let nonFactMealSources: Set<String> = [
        CoachTimelineEventSource.aiBackend.rawValue,
        "assistant",
        "assistantMessage",
    ]

    private static let trustedMealSources: Set<String> = [
        CoachTimelineEventSourceAttribution.userConfirmation.rawValue,
        CoachTimelineEventSourceAttribution.estimateFood.rawValue,
        "coachUI",
        "dailyLog",
        "manual",
        "user",
    ]

    static func validateAndCorrect(
        _ packet: CoachContextPacketV2,
        byteLimit: Int = CoachContextPacketV2Limits.defaultMaxEncodedBytes,
        calendar: Calendar = .current
    ) -> CoachContextValidationResult {
        var corrected = packet.clampedForTransport()
        var issues: [CoachContextValidationIssue] = []

        issues.append(contentsOf: validateCaloriesAgainstConfirmedFood(corrected, calendar: calendar))
        issues.append(contentsOf: validateMacrosAgainstConfirmedFood(corrected, calendar: calendar))
        issues.append(contentsOf: validateMacrosNonNegative(corrected))
        issues.append(contentsOf: validateWaterNonNegative(corrected))
        issues.append(contentsOf: validateRemainingValues(corrected))
        issues.append(contentsOf: validateOverTargetFlags(corrected))
        issues.append(contentsOf: validatePendingRejectedExcluded(corrected, calendar: calendar))
        issues.append(contentsOf: validateAssistantTextNotInStructuredFacts(corrected))
        issues.append(contentsOf: validateTimelineSorted(corrected))
        issues.append(contentsOf: validateLocalDateTimezone(corrected, calendar: calendar))
        issues.append(contentsOf: validateTimelineEventLocalDates(corrected, calendar: calendar))
        issues.append(contentsOf: validateStepsSource(corrected))
        issues.append(contentsOf: validateWorkoutSource(corrected))
        issues.append(contentsOf: validateRecentMealsSourceAttribution(corrected))
        issues.append(contentsOf: validateHealthStepsNotSilentlyZero(corrected))
        issues.append(contentsOf: validateHealthWorkoutsNotSilentlyZero(corrected))
        issues.append(contentsOf: validateMissingDataPopulated(corrected))
        issues.append(contentsOf: validateRejectedEventsExcluded(corrected))
        issues.append(contentsOf: validateEditDeleteConsistency(corrected))
        issues.append(contentsOf: validateCorruptedTimelinePayload(corrected))
        issues.append(contentsOf: validatePrivacySensitiveContent(corrected))
        issues.append(contentsOf: validateContextSize(corrected, byteLimit: byteLimit))

        corrected = applyCorrections(
            to: corrected,
            issues: issues,
            byteLimit: byteLimit,
            calendar: calendar
        )

        let result = CoachContextValidationResult(issues: issues, correctedPacket: corrected)
        report(result)
        return result
    }

    // MARK: Reporting

    static func report(_ result: CoachContextValidationResult) {
        guard !result.issues.isEmpty else { return }

        #if DEBUG
        let detail = result.issues
            .map { "[\($0.rule.rawValue)] \($0.message)" }
            .joined(separator: "; ")
        logger.error("CoachContextPacketV2 validation failed: \(detail, privacy: .public)")
        #else
        let summary = redactedSummary(for: result)
        logger.error("CoachContextPacketV2 validation failed: \(summary, privacy: .public)")
        #endif
    }

    static func redactedSummary(for result: CoachContextValidationResult) -> String {
        let rules = result.issues.map(\.rule.rawValue).joined(separator: ",")
        return "\(result.issues.count) issue(s) [\(rules)] packet=\(result.correctedPacket.redactedDebugDescription())"
    }

    // MARK: Validation rules

    private static func validateCaloriesAgainstConfirmedFood(
        _ packet: CoachContextPacketV2,
        calendar: Calendar
    ) -> [CoachContextValidationIssue] {
        guard let consumed = packet.today?.nutrition?.caloriesConsumed else { return [] }

        let confirmed = confirmedTodayFoodTotals(in: packet, calendar: calendar).calories
        guard abs(consumed - confirmed) > calorieTolerance else { return [] }

        return [
            issue(
                .caloriesMatchConfirmedFood,
                "caloriesConsumed=\(consumed) but confirmed today food sum=\(confirmed)"
            )
        ]
    }

    private static func validateMacrosAgainstConfirmedFood(
        _ packet: CoachContextPacketV2,
        calendar: Calendar
    ) -> [CoachContextValidationIssue] {
        guard let nutrition = packet.today?.nutrition else { return [] }

        let confirmed = confirmedTodayFoodTotals(in: packet, calendar: calendar)
        var issues: [CoachContextValidationIssue] = []

        if let protein = nutrition.proteinConsumed,
           abs(protein - confirmed.protein) > macroTolerance {
            issues.append(
                issue(
                    .macrosMatchConfirmedFood,
                    "proteinConsumed=\(protein) but confirmed today protein sum=\(confirmed.protein)"
                )
            )
        }
        if let carbs = nutrition.carbsConsumed,
           abs(carbs - confirmed.carbs) > macroTolerance {
            issues.append(
                issue(
                    .macrosMatchConfirmedFood,
                    "carbsConsumed=\(carbs) but confirmed today carbs sum=\(confirmed.carbs)"
                )
            )
        }
        if let fat = nutrition.fatConsumed,
           abs(fat - confirmed.fat) > macroTolerance {
            issues.append(
                issue(
                    .macrosMatchConfirmedFood,
                    "fatConsumed=\(fat) but confirmed today fat sum=\(confirmed.fat)"
                )
            )
        }

        return issues
    }

    private static func validateMacrosNonNegative(_ packet: CoachContextPacketV2) -> [CoachContextValidationIssue] {
        guard let nutrition = packet.today?.nutrition else { return [] }

        var issues: [CoachContextValidationIssue] = []
        if let protein = nutrition.proteinConsumed, protein < 0 {
            issues.append(issue(.macrosNonNegative, "proteinConsumed is negative (\(protein))"))
        }
        if let carbs = nutrition.carbsConsumed, carbs < 0 {
            issues.append(issue(.macrosNonNegative, "carbsConsumed is negative (\(carbs))"))
        }
        if let fat = nutrition.fatConsumed, fat < 0 {
            issues.append(issue(.macrosNonNegative, "fatConsumed is negative (\(fat))"))
        }
        return issues
    }

    private static func validateWaterNonNegative(_ packet: CoachContextPacketV2) -> [CoachContextValidationIssue] {
        guard let water = packet.today?.hydration?.waterConsumedMl, water < 0 else { return [] }
        return [issue(.waterNonNegative, "waterConsumedMl is negative (\(water))")]
    }

    private static func validateRemainingValues(_ packet: CoachContextPacketV2) -> [CoachContextValidationIssue] {
        guard let today = packet.today,
              let targets = today.targets,
              let nutrition = today.nutrition
        else { return [] }

        var issues: [CoachContextValidationIssue] = []

        if let calorieTarget = targets.calorieTarget,
           let consumed = nutrition.caloriesConsumed,
           let remaining = nutrition.caloriesRemaining {
            let expected = calorieTarget - consumed
            if remaining != expected {
                issues.append(
                    issue(
                        .remainingValuesConsistent,
                        "caloriesRemaining=\(remaining) expected \(expected)"
                    )
                )
            }
        }

        if let proteinTarget = targets.proteinTarget,
           let consumed = nutrition.proteinConsumed,
           let remaining = nutrition.proteinRemaining {
            let expected = proteinTarget - consumed
            if abs(remaining - expected) > 0.05 {
                issues.append(
                    issue(
                        .remainingValuesConsistent,
                        "proteinRemaining=\(remaining) expected \(expected)"
                    )
                )
            }
        }

        if let carbsTarget = targets.carbsTarget,
           let consumed = nutrition.carbsConsumed,
           let remaining = nutrition.carbsRemaining {
            let expected = carbsTarget - consumed
            if abs(remaining - expected) > 0.05 {
                issues.append(
                    issue(
                        .remainingValuesConsistent,
                        "carbsRemaining=\(remaining) expected \(expected)"
                    )
                )
            }
        }

        if let fatTarget = targets.fatTarget,
           let consumed = nutrition.fatConsumed,
           let remaining = nutrition.fatRemaining {
            let expected = fatTarget - consumed
            if abs(remaining - expected) > 0.05 {
                issues.append(
                    issue(
                        .remainingValuesConsistent,
                        "fatRemaining=\(remaining) expected \(expected)"
                    )
                )
            }
        }

        if let waterTarget = targets.waterTargetMl,
           let consumed = today.hydration?.waterConsumedMl,
           let remaining = today.hydration?.waterRemainingMl {
            let expected = waterTarget - consumed
            if remaining != expected {
                issues.append(
                    issue(
                        .remainingValuesConsistent,
                        "waterRemainingMl=\(remaining) expected \(expected)"
                    )
                )
            }
        }

        return issues
    }

    private static func validateOverTargetFlags(_ packet: CoachContextPacketV2) -> [CoachContextValidationIssue] {
        guard let today = packet.today else { return [] }

        var issues: [CoachContextValidationIssue] = []

        if let nutrition = today.nutrition {
            if let remaining = nutrition.caloriesRemaining,
               (remaining < 0) != (nutrition.caloriesOverTarget == true) {
                issues.append(issue(.overTargetFlagsConsistent, "caloriesOverTarget does not match remaining sign"))
            }
            if let remaining = nutrition.proteinRemaining,
               (remaining < 0) != (nutrition.proteinOverTarget == true) {
                issues.append(issue(.overTargetFlagsConsistent, "proteinOverTarget does not match remaining sign"))
            }
            if let remaining = nutrition.carbsRemaining,
               (remaining < 0) != (nutrition.carbsOverTarget == true) {
                issues.append(issue(.overTargetFlagsConsistent, "carbsOverTarget does not match remaining sign"))
            }
            if let remaining = nutrition.fatRemaining,
               (remaining < 0) != (nutrition.fatOverTarget == true) {
                issues.append(issue(.overTargetFlagsConsistent, "fatOverTarget does not match remaining sign"))
            }
        }

        if let hydration = today.hydration,
           let remaining = hydration.waterRemainingMl,
           (remaining < 0) != (hydration.waterOverTarget == true) {
            issues.append(issue(.overTargetFlagsConsistent, "waterOverTarget does not match remaining sign"))
        }

        return issues
    }

    private static func validatePendingRejectedExcluded(
        _ packet: CoachContextPacketV2,
        calendar: Calendar
    ) -> [CoachContextValidationIssue] {
        guard let consumed = packet.today?.nutrition?.caloriesConsumed else { return [] }

        let confirmed = confirmedTodayFoodTotals(in: packet, calendar: calendar).calories
        let speculative = pendingRejectedTodayFoodCalories(in: packet, calendar: calendar)
        guard speculative > 0, consumed > confirmed + calorieTolerance else { return [] }

        return [
            issue(
                .pendingRejectedNotInTotals,
                "caloriesConsumed=\(consumed) may include pending/rejected estimates (\(speculative) kcal speculative)"
            )
        ]
    }

    private static func validateAssistantTextNotInStructuredFacts(
        _ packet: CoachContextPacketV2
    ) -> [CoachContextValidationIssue] {
        var issues: [CoachContextValidationIssue] = []

        let assistantClaims = assistantClaimedCalories(in: packet)
        let confirmedCalories = confirmedTodayFoodTotals(in: packet, calendar: .current).calories

        if assistantClaims > confirmedCalories + calorieTolerance {
            issues.append(
                issue(
                    .assistantTextNotInStructuredFacts,
                    "assistant chat implies \(assistantClaims) kcal but confirmed food totals=\(confirmedCalories)"
                )
            )
        }

        let orphanMeals = packet.recentMealsStructured.filter(isAssistantPromotedMeal)
        if !orphanMeals.isEmpty {
            issues.append(
                issue(
                    .assistantTextNotInStructuredFacts,
                    "recentMealsStructured contains \(orphanMeals.count) meal(s) without confirmed log attribution"
                )
            )
        }

        return issues
    }

    private static func validateTimelineSorted(_ packet: CoachContextPacketV2) -> [CoachContextValidationIssue] {
        let events = packet.timeline.recentEvents
        guard events.count > 1 else { return [] }

        let timestamps = events.map(\.timestamp)
        let sorted = timestamps.sorted()
        guard timestamps != sorted else { return [] }

        return [issue(.timelineSorted, "timeline.recentEvents timestamps are not ascending")]
    }

    private static func validateLocalDateTimezone(
        _ packet: CoachContextPacketV2,
        calendar: Calendar
    ) -> [CoachContextValidationIssue] {
        var resolvedCalendar = calendar
        if let timezone = TimeZone(identifier: packet.meta.timezoneIdentifier) {
            resolvedCalendar.timeZone = timezone
        }

        let expected = CoachContextMeta.make(
            generatedAt: packet.meta.generatedAt,
            calendar: resolvedCalendar
        ).localDate

        guard packet.meta.localDate != expected else { return [] }
        return [
            issue(
                .localDateTimezoneConsistent,
                "meta.localDate=\(packet.meta.localDate) expected \(expected) for timezone \(packet.meta.timezoneIdentifier)"
            )
        ]
    }

    private static func validateTimelineEventLocalDates(
        _ packet: CoachContextPacketV2,
        calendar: Calendar
    ) -> [CoachContextValidationIssue] {
        let localDate = packet.meta.localDate
        var issues: [CoachContextValidationIssue] = []

        for meal in packet.recentMealsStructured where meal.localDate == localDate {
            guard let loggedAt = meal.loggedAt else { continue }
            let derived = eventLocalDate(
                timestamp: loggedAt,
                timezoneIdentifier: packet.meta.timezoneIdentifier,
                calendar: calendar
            )
            if derived != localDate {
                issues.append(
                    issue(
                        .timelineEventLocalDateConsistent,
                        "meal \(meal.name) localDate=\(localDate) but loggedAt maps to \(derived)"
                    )
                )
            }
        }

        return issues
    }

    private static func validateStepsSource(_ packet: CoachContextPacketV2) -> [CoachContextValidationIssue] {
        guard let steps = packet.today?.steps else {
            if packet.missingData.stepsMissing || packet.missingData.stepsUnavailable {
                return []
            }
            return [issue(.stepsSourceExplicit, "steps are nil but missingData does not flag steps missing/unavailable")]
        }

        let source = steps.source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard source.isEmpty || source == "unknown" else { return [] }
        return [issue(.stepsSourceExplicit, "steps value present without explicit source")]
    }

    private static func validateWorkoutSource(_ packet: CoachContextPacketV2) -> [CoachContextValidationIssue] {
        guard let training = packet.training else { return [] }

        var issues: [CoachContextValidationIssue] = []

        if let workoutsToday = training.workoutsToday, workoutsToday > 0 {
            let missingSources = training.workouts.filter {
                let source = ($0.source ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return source.isEmpty || source == "unknown"
            }
            if !missingSources.isEmpty {
                issues.append(
                    issue(.workoutSourceExplicit, "workoutsToday=\(workoutsToday) but workout source is missing")
                )
            }
        }

        if training.workoutsToday == nil,
           !training.workouts.isEmpty,
           !packet.missingData.workoutsUnavailable,
           !packet.missingData.workoutPermissionDeniedOrUnavailable {
            issues.append(
                issue(.workoutSourceExplicit, "workouts listed but workoutsToday is nil without unavailable flag")
            )
        }

        return issues
    }

    private static func validateRecentMealsSourceAttribution(
        _ packet: CoachContextPacketV2
    ) -> [CoachContextValidationIssue] {
        let missing = packet.recentMealsStructured.filter { meal in
            guard meal.calories != nil || meal.proteinGrams != nil else { return false }
            let source = (meal.source ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return meal.linkedEntryId == nil && source.isEmpty
        }

        guard !missing.isEmpty else { return [] }
        return [
            issue(
                .recentMealsSourceAttribution,
                "recentMealsStructured has \(missing.count) meal(s) missing source and linkedEntryId"
            )
        ]
    }

    private static func validateHealthStepsNotSilentlyZero(
        _ packet: CoachContextPacketV2
    ) -> [CoachContextValidationIssue] {
        guard let steps = packet.today?.steps else { return [] }

        let healthUnavailable = packet.missingData.stepsMissing
            || packet.missingData.stepsUnavailable
            || packet.missingData.healthKitDenied
            || packet.missingData.healthKitUnavailable

        guard steps.value == 0, healthUnavailable else { return [] }
        return [
            issue(
                .healthStepsNotSilentlyZero,
                "steps reported as 0 while health data is missing or unavailable"
            )
        ]
    }

    private static func validateHealthWorkoutsNotSilentlyZero(
        _ packet: CoachContextPacketV2
    ) -> [CoachContextValidationIssue] {
        let healthUnavailable = packet.missingData.workoutPermissionDeniedOrUnavailable
            || packet.missingData.workoutsUnavailable
            || packet.missingData.healthKitDenied
            || packet.missingData.healthKitUnavailable

        guard healthUnavailable else { return [] }

        if packet.training?.workoutsToday == 0,
           packet.training?.workouts.isEmpty != false {
            return [
                issue(
                    .healthWorkoutsNotSilentlyZero,
                    "workoutsToday=0 while HealthKit workouts are unavailable or denied"
                )
            ]
        }

        return []
    }

    private static func validateMissingDataPopulated(_ packet: CoachContextPacketV2) -> [CoachContextValidationIssue] {
        var issues: [CoachContextValidationIssue] = []

        if packet.today?.steps == nil,
           !packet.missingData.stepsMissing,
           !packet.missingData.stepsUnavailable {
            issues.append(issue(.missingDataPopulated, "steps nil without stepsMissing/stepsUnavailable"))
        }

        if packet.today?.weight?.weightKg == nil, !packet.missingData.weightMissing {
            issues.append(issue(.missingDataPopulated, "weight nil without weightMissing"))
        }

        if packet.recentMealsStructured.isEmpty, !packet.missingData.noRecentMeals {
            issues.append(issue(.missingDataPopulated, "no recent meals without noRecentMeals"))
        }

        if packet.timeline.recentEvents.isEmpty, !packet.missingData.noTimelineHistory {
            issues.append(issue(.missingDataPopulated, "empty timeline without noTimelineHistory"))
        }

        return issues
    }

    private static func validateRejectedEventsExcluded(
        _ packet: CoachContextPacketV2
    ) -> [CoachContextValidationIssue] {
        let ineligible = packet.timeline.recentEvents.filter { !isExportEligibleTimelineEvent($0) }
        guard !ineligible.isEmpty else { return [] }
        return [
            issue(
                .rejectedEventsExcludedFromTimeline,
                "timeline contains \(ineligible.count) rejected/pending/failed export-ineligible event(s)"
            )
        ]
    }

    private static func validateEditDeleteConsistency(
        _ packet: CoachContextPacketV2
    ) -> [CoachContextValidationIssue] {
        let deletedEntryIDs = Set(
            packet.timeline.recentEvents
                .filter { $0.type == CoachTimelineEventType.foodDeleted.rawValue }
                .compactMap(\.linkedEntryId)
        )

        guard !deletedEntryIDs.isEmpty else { return [] }

        let staleMeals = packet.recentMealsStructured.filter { meal in
            guard let entryID = meal.linkedEntryId else { return false }
            return deletedEntryIDs.contains(entryID)
        }

        guard !staleMeals.isEmpty else { return [] }
        return [
            issue(
                .editDeleteTimelineConsistency,
                "recentMealsStructured still includes \(staleMeals.count) deleted meal(s)"
            )
        ]
    }

    private static func validateCorruptedTimelinePayload(
        _ packet: CoachContextPacketV2
    ) -> [CoachContextValidationIssue] {
        var issues: [CoachContextValidationIssue] = []

        for event in packet.timeline.recentEvents where event.type == CoachTimelineEventType.foodLogged.rawValue {
            if let raw = event.compactPayload?["kcal"], let parsed = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)), parsed < 0 {
                issues.append(
                    issue(
                        .corruptedTimelinePayload,
                        "foodLogged event \(event.id) has negative kcal payload"
                    )
                )
            } else if event.compactPayload?["kcal"] != nil, parseTimelineCalories(event) == nil {
                issues.append(
                    issue(
                        .corruptedTimelinePayload,
                        "foodLogged event \(event.id) has non-numeric kcal payload"
                    )
                )
            }
        }

        return issues
    }

    private static func validatePrivacySensitiveContent(
        _ packet: CoachContextPacketV2
    ) -> [CoachContextValidationIssue] {
        var issues: [CoachContextValidationIssue] = []

        if packet.timeline.recentEvents.contains(where: {
            $0.type == CoachTimelineEventType.authError.rawValue
                || $0.type == CoachTimelineEventType.backendError.rawValue
        }) {
            issues.append(issue(.privacySensitiveContent, "timeline includes backend/auth error events"))
        }

        if containsSensitiveString(packet.currentUserMessage) {
            issues.append(issue(.privacySensitiveContent, "currentUserMessage contains sensitive content"))
        }

        for message in packet.recentChatMessages where containsSensitiveString(message.text) {
            issues.append(issue(.privacySensitiveContent, "recentChatMessages contain sensitive content"))
            break
        }

        for event in packet.timeline.recentEvents {
            if containsSensitiveString(event.summary) || payloadContainsSensitiveData(event.compactPayload) {
                issues.append(issue(.privacySensitiveContent, "timeline event contains sensitive content"))
                break
            }
        }

        return issues
    }

    private static func validateContextSize(
        _ packet: CoachContextPacketV2,
        byteLimit: Int
    ) -> [CoachContextValidationIssue] {
        guard packet.estimatedEncodedByteCount() > byteLimit else { return [] }
        return [
            issue(
                .contextSizeBelowThreshold,
                "encoded context size \(packet.estimatedEncodedByteCount()) exceeds \(byteLimit) bytes"
            )
        ]
    }

    // MARK: Corrections

    private static func applyCorrections(
        to packet: CoachContextPacketV2,
        issues: [CoachContextValidationIssue],
        byteLimit: Int,
        calendar: Calendar
    ) -> CoachContextPacketV2 {
        var corrected = packet

        if !issues.isEmpty {
            corrected.generationMode = degradedMode(for: corrected.generationMode)
        }

        if issues.contains(where: { $0.rule == .timelineSorted }) {
            corrected.timeline.recentEvents.sort { $0.timestamp < $1.timestamp }
        }

        if issues.contains(where: { $0.rule == .localDateTimezoneConsistent }) {
            var resolvedCalendar = calendar
            if let timezone = TimeZone(identifier: corrected.meta.timezoneIdentifier) {
                resolvedCalendar.timeZone = timezone
            }
            let meta = CoachContextMeta.make(
                generatedAt: corrected.meta.generatedAt,
                calendar: resolvedCalendar
            )
            corrected.meta.localDate = meta.localDate
            corrected.meta.localTime = meta.localTime
        }

        if issues.contains(where: {
            $0.rule == .rejectedEventsExcludedFromTimeline
                || $0.rule == .privacySensitiveContent
        }) {
            corrected.timeline.recentEvents = corrected.timeline.recentEvents.filter(isExportEligibleTimelineEvent)
            corrected.timeline.recentEvents = corrected.timeline.recentEvents.map(sanitizeTimelineEventForPrivacy)
        }

        if issues.contains(where: { $0.rule == .assistantTextNotInStructuredFacts }) {
            corrected.recentMealsStructured = corrected.recentMealsStructured.filter { !isAssistantPromotedMeal($0) }
        }

        if issues.contains(where: { $0.rule == .editDeleteTimelineConsistency }) {
            let deletedEntryIDs = Set(
                corrected.timeline.recentEvents
                    .filter { $0.type == CoachTimelineEventType.foodDeleted.rawValue }
                    .compactMap(\.linkedEntryId)
            )
            corrected.recentMealsStructured = corrected.recentMealsStructured.filter { meal in
                guard let entryID = meal.linkedEntryId else { return true }
                return !deletedEntryIDs.contains(entryID)
            }
        }

        if issues.contains(where: { $0.rule == .corruptedTimelinePayload }) {
            corrected.timeline.recentEvents = corrected.timeline.recentEvents.map { event in
                guard event.type == CoachTimelineEventType.foodLogged.rawValue else { return event }
                guard let kcal = parseTimelineCalories(event), kcal < 0 else { return event }
                var sanitized = event
                sanitized.compactPayload?["kcal"] = "0"
                return sanitized
            }
        }

        if issues.contains(where: { $0.rule == .recentMealsSourceAttribution }) {
            corrected.recentMealsStructured = corrected.recentMealsStructured.map { meal in
                var copy = meal
                if copy.linkedEntryId == nil,
                   (copy.source ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   copy.calories != nil || copy.proteinGrams != nil {
                    copy.source = "unknown"
                }
                return copy
            }
        }

        if var today = corrected.today {
            if var nutrition = today.nutrition {
                if let protein = nutrition.proteinConsumed, protein < 0 {
                    nutrition.proteinConsumed = 0
                }
                if let carbs = nutrition.carbsConsumed, carbs < 0 {
                    nutrition.carbsConsumed = 0
                }
                if let fat = nutrition.fatConsumed, fat < 0 {
                    nutrition.fatConsumed = 0
                }

                if issues.contains(where: {
                    $0.rule == .caloriesMatchConfirmedFood
                        || $0.rule == .pendingRejectedNotInTotals
                        || $0.rule == .assistantTextNotInStructuredFacts
                }) {
                    let confirmed = confirmedTodayFoodTotals(in: corrected, calendar: calendar)
                    nutrition.caloriesConsumed = confirmed.calories
                    nutrition.proteinConsumed = confirmed.protein
                    nutrition.carbsConsumed = confirmed.carbs
                    nutrition.fatConsumed = confirmed.fat
                } else if issues.contains(where: { $0.rule == .macrosMatchConfirmedFood }) {
                    let confirmed = confirmedTodayFoodTotals(in: corrected, calendar: calendar)
                    nutrition.proteinConsumed = confirmed.protein
                    nutrition.carbsConsumed = confirmed.carbs
                    nutrition.fatConsumed = confirmed.fat
                }

                nutrition = recalculatedRemaining(nutrition: nutrition, targets: today.targets)
                today.nutrition = nutrition
            }

            if var hydration = today.hydration {
                if let water = hydration.waterConsumedMl, water < 0 {
                    hydration.waterConsumedMl = 0
                }
                if let target = today.targets?.waterTargetMl,
                   let consumed = hydration.waterConsumedMl {
                    hydration.waterRemainingMl = target - consumed
                    hydration.waterOverTarget = hydration.waterRemainingMl.map { $0 < 0 }
                }
                today.hydration = hydration
            }

            if var steps = today.steps,
               issues.contains(where: { $0.rule == .stepsSourceExplicit }) {
                if steps.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    steps.source = "healthKit"
                }
                today.steps = steps
            }

            if issues.contains(where: { $0.rule == .healthStepsNotSilentlyZero }) {
                today.steps = nil
            }

            corrected.today = today
        }

        if issues.contains(where: { $0.rule == .remainingValuesConsistent || $0.rule == .overTargetFlagsConsistent }),
           var today = corrected.today,
           var nutrition = today.nutrition {
            nutrition = recalculatedRemaining(nutrition: nutrition, targets: today.targets)
            today.nutrition = nutrition
            corrected.today = today
        }

        if issues.contains(where: { $0.rule == .workoutSourceExplicit }),
           var training = corrected.training {
            training.workouts = training.workouts.map { workout in
                var copy = workout
                let source = (copy.source ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if source.isEmpty || source == "unknown" {
                    copy.source = "healthKit"
                }
                return copy
            }
            corrected.training = training
        }

        if issues.contains(where: { $0.rule == .healthWorkoutsNotSilentlyZero }),
           var training = corrected.training {
            training.workoutsToday = nil
            corrected.training = training
        }

        if issues.contains(where: { $0.rule == .missingDataPopulated || $0.rule == .healthStepsNotSilentlyZero }) {
            corrected.missingData = correctedMissingData(for: corrected)
        }

        if issues.contains(where: { $0.rule == .healthWorkoutsNotSilentlyZero }) {
            corrected.missingData.workoutPermissionDeniedOrUnavailable = true
            corrected.missingData.workoutsUnavailable = true
        }

        if issues.contains(where: { $0.rule == .privacySensitiveContent }) {
            corrected.currentUserMessage = redactSensitiveString(corrected.currentUserMessage)
            corrected.recentChatMessages = corrected.recentChatMessages.map { message in
                var copy = message
                copy.text = redactSensitiveString(copy.text) ?? ""
                return copy
            }
        }

        if issues.contains(where: { $0.rule == .contextSizeBelowThreshold })
            || corrected.estimatedEncodedByteCount() > byteLimit {
            var compaction = corrected.sourceAttribution?.compaction
            corrected = CoachContextPacketV2SizeCompactor.compact(
                corrected,
                byteLimit: byteLimit,
                compaction: &compaction
            )
            if var attribution = corrected.sourceAttribution {
                attribution.compaction = compaction
                corrected.sourceAttribution = attribution
            }
            corrected.generationMode = degradedMode(for: corrected.generationMode)
        }

        return corrected.clampedForTransport()
    }

    // MARK: Helpers

    private static func issue(
        _ rule: CoachContextValidationRule,
        _ message: String
    ) -> CoachContextValidationIssue {
        CoachContextValidationIssue(rule: rule, message: message)
    }

    private struct ConfirmedFoodTotals {
        var calories: Int
        var protein: Double
        var carbs: Double
        var fat: Double
    }

    private static func confirmedTodayFoodTotals(
        in packet: CoachContextPacketV2,
        calendar: Calendar
    ) -> ConfirmedFoodTotals {
        let localDate = packet.meta.localDate

        let todayMeals = packet.recentMealsStructured.filter { $0.localDate == localDate }
        let mealTotals = ConfirmedFoodTotals(
            calories: todayMeals.compactMap(\.calories).reduce(0, +),
            protein: todayMeals.compactMap(\.proteinGrams).reduce(0, +),
            carbs: todayMeals.compactMap(\.carbsGrams).reduce(0, +),
            fat: todayMeals.compactMap(\.fatGrams).reduce(0, +)
        )

        let timelineTotals = confirmedTimelineFoodTotals(in: packet, calendar: calendar)

        if !todayMeals.isEmpty {
            return ConfirmedFoodTotals(
                calories: max(mealTotals.calories, timelineTotals.calories),
                protein: max(mealTotals.protein, timelineTotals.protein),
                carbs: max(mealTotals.carbs, timelineTotals.carbs),
                fat: max(mealTotals.fat, timelineTotals.fat)
            )
        }

        return timelineTotals
    }

    private static func confirmedTimelineFoodTotals(
        in packet: CoachContextPacketV2,
        calendar: Calendar
    ) -> ConfirmedFoodTotals {
        let localDate = packet.meta.localDate

        let events = packet.timeline.recentEvents.filter {
            $0.type == CoachTimelineEventType.foodLogged.rawValue
                && $0.status == CoachTimelineEventStatus.confirmed.rawValue
                && eventLocalDate($0, timezoneIdentifier: packet.meta.timezoneIdentifier, calendar: calendar) == localDate
        }

        return ConfirmedFoodTotals(
            calories: events.compactMap(parseTimelineCalories).filter { $0 > 0 }.reduce(0, +),
            protein: events.compactMap { parseTimelineMacro($0, key: "protein") }.reduce(0, +),
            carbs: events.compactMap { parseTimelineMacro($0, key: "carbs") }.reduce(0, +),
            fat: events.compactMap { parseTimelineMacro($0, key: "fat") }.reduce(0, +)
        )
    }

    private static func pendingRejectedTodayFoodCalories(
        in packet: CoachContextPacketV2,
        calendar: Calendar
    ) -> Int {
        let localDate = packet.meta.localDate

        return packet.timeline.recentEvents
            .filter {
                speculativeTimelineTypes.contains($0.type)
                    && eventLocalDate($0, timezoneIdentifier: packet.meta.timezoneIdentifier, calendar: calendar) == localDate
            }
            .compactMap(parseTimelineCalories)
            .reduce(0, +)
    }

    private static func parseTimelineCalories(_ event: CoachTimelineContextEvent) -> Int? {
        guard let raw = event.compactPayload?["kcal"] else { return nil }
        return Int(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func parseTimelineMacro(_ event: CoachTimelineContextEvent, key: String) -> Double? {
        guard let raw = event.compactPayload?[key] else { return nil }
        return Double(raw)
    }

    private static func eventLocalDate(
        _ event: CoachTimelineContextEvent,
        timezoneIdentifier: String,
        calendar: Calendar
    ) -> String {
        eventLocalDate(
            timestamp: event.timestamp,
            timezoneIdentifier: timezoneIdentifier,
            calendar: calendar
        )
    }

    private static func eventLocalDate(
        timestamp: Date,
        timezoneIdentifier: String,
        calendar: Calendar
    ) -> String {
        var resolvedCalendar = calendar
        resolvedCalendar.timeZone = TimeZone(identifier: timezoneIdentifier) ?? calendar.timeZone

        let formatter = DateFormatter()
        formatter.calendar = resolvedCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = resolvedCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: timestamp)
    }

    private static func recalculatedRemaining(
        nutrition: CoachTodayNutritionContext,
        targets: CoachTodayTargetsContext?
    ) -> CoachTodayNutritionContext {
        var updated = nutrition

        if let target = targets?.calorieTarget, let consumed = updated.caloriesConsumed {
            updated.caloriesRemaining = target - consumed
            updated.caloriesOverTarget = updated.caloriesRemaining.map { $0 < 0 }
        }
        if let target = targets?.proteinTarget, let consumed = updated.proteinConsumed {
            updated.proteinRemaining = target - consumed
            updated.proteinOverTarget = updated.proteinRemaining.map { $0 < 0 }
        }
        if let target = targets?.carbsTarget, let consumed = updated.carbsConsumed {
            updated.carbsRemaining = target - consumed
            updated.carbsOverTarget = updated.carbsRemaining.map { $0 < 0 }
        }
        if let target = targets?.fatTarget, let consumed = updated.fatConsumed {
            updated.fatRemaining = target - consumed
            updated.fatOverTarget = updated.fatRemaining.map { $0 < 0 }
        }

        return updated
    }

    private static func correctedMissingData(for packet: CoachContextPacketV2) -> CoachMissingDataContext {
        var missing = packet.missingData

        if packet.today?.steps == nil {
            missing.stepsMissing = true
        }
        if packet.today?.weight?.weightKg == nil {
            missing.weightMissing = true
        }
        if packet.recentMealsStructured.isEmpty {
            missing.noRecentMeals = true
        }
        if packet.timeline.recentEvents.isEmpty {
            missing.noTimelineHistory = true
        }

        return missing
    }

    private static func isExportEligibleTimelineEvent(_ event: CoachTimelineContextEvent) -> Bool {
        if event.status == CoachTimelineEventStatus.rejected.rawValue
            || event.status == CoachTimelineEventStatus.failed.rawValue
            || event.status == CoachTimelineEventStatus.superseded.rawValue {
            return false
        }
        if excludedTimelineTypes.contains(event.type) {
            return false
        }
        if event.status == CoachTimelineEventStatus.pending.rawValue,
           event.type != CoachTimelineEventType.pendingConfirmationCreated.rawValue {
            return false
        }
        return true
    }

    private static func isAssistantPromotedMeal(_ meal: CoachRecentMealContext) -> Bool {
        if meal.linkedEntryId != nil { return false }
        let source = (meal.source ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trustedMealSources.contains(where: { source.contains($0.lowercased()) }) {
            return false
        }
        return source.isEmpty || nonFactMealSources.contains(where: { source.contains($0.lowercased()) })
    }

    private static func assistantClaimedCalories(in packet: CoachContextPacketV2) -> Int {
        let pattern = #"(\d{2,4})\s*(?:kcal|cal|calories)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return 0
        }

        let assistantText = packet.recentChatMessages
            .filter { $0.role == ChatMessageRole.assistant.rawValue }
            .map(\.text)
            .joined(separator: " ")

        let range = NSRange(assistantText.startIndex..<assistantText.endIndex, in: assistantText)
        let matches = regex.matches(in: assistantText, options: [], range: range)
        return matches.compactMap { match -> Int? in
            guard let valueRange = Range(match.range(at: 1), in: assistantText) else { return nil }
            return Int(assistantText[valueRange])
        }.max() ?? 0
    }

    private static func containsSensitiveString(_ value: String?) -> Bool {
        guard let value, !value.isEmpty else { return false }
        let lowered = value.lowercased()
        if lowered.contains("data:image") { return true }
        if lowered.contains("imagejpegbase64") { return true }
        if lowered.contains("bearer ") { return true }
        if lowered.contains("sk-") { return true }
        if lowered.contains("api_key") || lowered.contains("apikey") { return true }
        if value.count > 512, value.unicodeScalars.allSatisfy({ $0.isASCII }) {
            let base64Charset = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
            if CharacterSet(charactersIn: value).isSubset(of: base64Charset) {
                return true
            }
        }
        return false
    }

    private static func payloadContainsSensitiveData(_ payload: [String: String]?) -> Bool {
        guard let payload else { return false }
        return payload.values.contains(where: { containsSensitiveString($0) })
    }

    private static func sanitizeTimelineEventForPrivacy(_ event: CoachTimelineContextEvent) -> CoachTimelineContextEvent {
        var copy = event
        copy.summary = redactSensitiveString(copy.summary) ?? copy.summary
        if let payload = copy.compactPayload {
            copy.compactPayload = Dictionary(uniqueKeysWithValues: payload.map { key, value in
                (key, redactSensitiveString(value) ?? value)
            })
        }
        return copy
    }

    private static func redactSensitiveString(_ value: String?) -> String? {
        guard let value else { return nil }
        guard containsSensitiveString(value) else { return value }
        return "<redacted>"
    }

    private static func degradedMode(for mode: CoachContextGenerationMode) -> CoachContextGenerationMode {
        switch mode {
        case .live, .preview:
            return .degraded
        default:
            return mode
        }
    }
}
