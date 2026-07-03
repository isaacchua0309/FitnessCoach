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
    case macrosNonNegative
    case waterNonNegative
    case remainingValuesConsistent
    case pendingRejectedNotInTotals
    case timelineSorted
    case localDateTimezoneConsistent
    case stepsSourceExplicit
    case workoutSourceExplicit
    case missingDataPopulated
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

    static func validateAndCorrect(
        _ packet: CoachContextPacketV2,
        byteLimit: Int = CoachContextPacketV2Limits.defaultMaxEncodedBytes,
        calendar: Calendar = .current
    ) -> CoachContextValidationResult {
        var corrected = packet.clampedForTransport()
        var issues: [CoachContextValidationIssue] = []

        issues.append(contentsOf: validateCaloriesAgainstConfirmedFood(corrected, calendar: calendar))
        issues.append(contentsOf: validateMacrosNonNegative(corrected))
        issues.append(contentsOf: validateWaterNonNegative(corrected))
        issues.append(contentsOf: validateRemainingValues(corrected))
        issues.append(contentsOf: validatePendingRejectedExcluded(corrected, calendar: calendar))
        issues.append(contentsOf: validateTimelineSorted(corrected))
        issues.append(contentsOf: validateLocalDateTimezone(corrected, calendar: calendar))
        issues.append(contentsOf: validateStepsSource(corrected))
        issues.append(contentsOf: validateWorkoutSource(corrected))
        issues.append(contentsOf: validateMissingDataPopulated(corrected))
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

        let confirmed = confirmedTodayFoodCalories(in: packet, calendar: calendar)
        guard abs(consumed - confirmed) > calorieTolerance else { return [] }

        return [
            CoachContextValidationIssue(
                rule: .caloriesMatchConfirmedFood,
                message: "caloriesConsumed=\(consumed) but confirmed today food sum=\(confirmed)"
            )
        ]
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

    private static func validatePendingRejectedExcluded(
        _ packet: CoachContextPacketV2,
        calendar: Calendar
    ) -> [CoachContextValidationIssue] {
        guard let consumed = packet.today?.nutrition?.caloriesConsumed else { return [] }

        let confirmed = confirmedTodayFoodCalories(in: packet, calendar: calendar)
        let speculative = pendingRejectedTodayFoodCalories(in: packet, calendar: calendar)
        guard speculative > 0, consumed > confirmed + calorieTolerance else { return [] }

        return [
            issue(
                .pendingRejectedNotInTotals,
                "caloriesConsumed=\(consumed) may include pending/rejected estimates (\(speculative) kcal speculative)"
            )
        ]
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

        if (packet.training?.workoutsToday == nil || packet.training?.workoutsToday == 0),
           packet.training?.workouts.isEmpty != false,
           !packet.missingData.workoutsUnavailable,
           !packet.missingData.workoutPermissionDeniedOrUnavailable,
           packet.today?.workoutCaloriesBurned == nil {
            // workouts unknown is acceptable when training context omitted entirely
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
        guard !issues.isEmpty else { return packet }

        var corrected = packet

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
                    $0.rule == .caloriesMatchConfirmedFood || $0.rule == .pendingRejectedNotInTotals
                }) {
                    let confirmed = confirmedTodayFoodCalories(in: corrected, calendar: calendar)
                    nutrition.caloriesConsumed = confirmed
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

            corrected.today = today
        }

        if issues.contains(where: { $0.rule == .remainingValuesConsistent }),
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

        if issues.contains(where: { $0.rule == .missingDataPopulated }) {
            corrected.missingData = correctedMissingData(for: corrected)
        }

        if issues.contains(where: { $0.rule == .contextSizeBelowThreshold })
            || corrected.estimatedEncodedByteCount() > byteLimit {
            corrected = CoachContextPacketV2SizeCompactor.compact(corrected, byteLimit: byteLimit)
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

    private static func confirmedTodayFoodCalories(
        in packet: CoachContextPacketV2,
        calendar: Calendar
    ) -> Int {
        let localDate = packet.meta.localDate

        let mealSum = packet.recentMealsStructured
            .filter { $0.localDate == localDate }
            .compactMap(\.calories)
            .reduce(0, +)

        let timelineSum = packet.timeline.recentEvents
            .filter {
                $0.type == CoachTimelineEventType.foodLogged.rawValue
                    && $0.status == CoachTimelineEventStatus.confirmed.rawValue
                    && eventLocalDate($0, timezoneIdentifier: packet.meta.timezoneIdentifier, calendar: calendar) == localDate
            }
            .compactMap { event -> Int? in
                if let kcal = event.compactPayload?["kcal"] {
                    return Int(kcal)
                }
                return nil
            }
            .reduce(0, +)

        return max(mealSum, timelineSum)
    }

    private static func pendingRejectedTodayFoodCalories(
        in packet: CoachContextPacketV2,
        calendar: Calendar
    ) -> Int {
        let localDate = packet.meta.localDate
        let speculativeTypes: Set<String> = [
            CoachTimelineEventType.foodEstimateCreated.rawValue,
            CoachTimelineEventType.foodRejected.rawValue,
            CoachTimelineEventType.pendingConfirmationCreated.rawValue,
            CoachTimelineEventType.pendingConfirmationRejected.rawValue,
        ]

        return packet.timeline.recentEvents
            .filter {
                speculativeTypes.contains($0.type)
                    && eventLocalDate($0, timezoneIdentifier: packet.meta.timezoneIdentifier, calendar: calendar) == localDate
            }
            .compactMap { event -> Int? in
                if let kcal = event.compactPayload?["kcal"] {
                    return Int(kcal)
                }
                return nil
            }
            .reduce(0, +)
    }

    private static func eventLocalDate(
        _ event: CoachTimelineContextEvent,
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
        return formatter.string(from: event.timestamp)
    }

    private static func recalculatedRemaining(
        nutrition: CoachTodayNutritionContext,
        targets: CoachTodayTargetsContext?
    ) -> CoachTodayNutritionContext {
        var updated = nutrition

        if let target = targets?.calorieTarget, let consumed = updated.caloriesConsumed {
            updated.caloriesRemaining = target - consumed
        }
        if let target = targets?.proteinTarget, let consumed = updated.proteinConsumed {
            updated.proteinRemaining = target - consumed
        }
        if let target = targets?.carbsTarget, let consumed = updated.carbsConsumed {
            updated.carbsRemaining = target - consumed
        }
        if let target = targets?.fatTarget, let consumed = updated.fatConsumed {
            updated.fatRemaining = target - consumed
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
}
