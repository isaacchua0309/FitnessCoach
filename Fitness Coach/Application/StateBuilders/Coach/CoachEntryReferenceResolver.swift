//
//  CoachEntryReferenceResolver.swift
//  Fitness Coach
//
//  Resolves edit/delete food targets using linkedEntryId, pending confirmation,
//  timeline events, and recentMealsStructured with explicit confidence.
//

import Foundation

enum CoachEntryReferenceConfidence: String, Equatable, Sendable {
    case high
    case medium
    case low
}

enum CoachEntryReferenceOutcome: Equatable, Sendable {
    case target(
        linkedEntryId: UUID?,
        linkedTimelineEventId: UUID?,
        confidence: CoachEntryReferenceConfidence,
        pendingFoodDraft: AIFoodConfirmationDraft?
    )
    case clarify(message: String)
    case blocked(message: String)
}

struct CoachEntryReferenceResolution: Equatable, Sendable {
    var outcome: CoachEntryReferenceOutcome
    var enrichedAction: AICommandAction?
}

enum CoachEntryReferenceResolver {

    private static let demonstrativeTokens = [
        "that", "this", "it", "the last one", "last one", "last meal", "most recent"
    ]

    // MARK: - Public API

    static func linkedEntryId(fromSelector selector: String?) -> UUID? {
        guard let raw = selector?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let uuid = UUID(uuidString: raw)
        else {
            return nil
        }
        return uuid
    }

    static func resolve(
        action: AICommandAction,
        context: CoachContextPacketV2,
        pendingConfirmation: CoachPendingConfirmation? = nil,
        isUndoFlow: Bool = false
    ) -> CoachEntryReferenceResolution {
        guard action.type == .editEntry || action.type == .deleteEntry else {
            return CoachEntryReferenceResolution(
                outcome: .blocked(message: CoachResponseBuilder.entryReferenceUnsupportedAction),
                enrichedAction: action
            )
        }

        if let pendingResolution = resolvePendingConfirmation(
            action: action,
            pendingConfirmation: pendingConfirmation
        ) {
            return pendingResolution
        }

        if let explicitId = action.linkedEntryId ?? linkedEntryId(fromSelector: action.targetEntrySelector) {
            return resolveExplicitEntryId(
                explicitId,
                action: action,
                context: context,
                isUndoFlow: isUndoFlow
            )
        }

        let selector = normalizedSelector(action.targetEntrySelector)
        let events = eligibleFoodTargetEvents(in: context.timeline.recentEvents, isUndoFlow: isUndoFlow)
        let meals = eligibleMeals(from: context.recentMealsStructured, events: events)

        if referencesDemonstrative(selector) || selector.isEmpty {
            if let resolution = resolveMostRecentFoodEvent(
                events: events,
                action: action,
                confidence: selector.isEmpty ? .medium : .medium
            ) {
                return resolution
            }
        }

        if let mealType = mealTypeHint(from: action, selector: selector) {
            if let resolution = resolveMealType(
                mealType,
                events: events,
                meals: meals,
                action: action
            ) {
                return resolution
            }
        }

        if !selector.isEmpty {
            if let resolution = resolveMealName(
                selector: selector,
                meals: meals,
                events: events,
                action: action
            ) {
                return resolution
            }

            if referencesDemonstrative(selector),
               let resolution = resolveDemonstrativeTimelineReference(
                events: events,
                action: action
               ) {
                return resolution
            }
        }

        return CoachEntryReferenceResolution(
            outcome: .clarify(message: CoachResponseBuilder.entryReferenceClarification()),
            enrichedAction: nil
        )
    }

    static func enrichAction(
        _ action: AICommandAction,
        context: CoachContextPacketV2,
        pendingConfirmation: CoachPendingConfirmation? = nil,
        isUndoFlow: Bool = false
    ) -> CoachEntryReferenceResolution {
        let resolution = resolve(
            action: action,
            context: context,
            pendingConfirmation: pendingConfirmation,
            isUndoFlow: isUndoFlow
        )
        guard case .target(let linkedEntryId, let resolvedTimelineEventId, _, _) = resolution.outcome else {
            return resolution
        }

        var enriched = action
        enriched.linkedEntryId = linkedEntryId
        enriched.linkedTimelineEventId = resolvedTimelineEventId
            ?? Self.linkedTimelineEventId(forEntryId: linkedEntryId, in: context.timeline.recentEvents)
        return CoachEntryReferenceResolution(outcome: resolution.outcome, enrichedAction: enriched)
    }

    static func linkedTimelineEventId(
        forEntryId entryId: UUID?,
        in events: [CoachTimelineContextEvent]
    ) -> UUID? {
        guard let entryId else { return nil }
        return eligibleFoodTargetEvents(in: events, isUndoFlow: false)
            .last(where: { $0.linkedEntryId == entryId })?
            .id
    }

    // MARK: - Priority: pending confirmation

    private static func resolvePendingConfirmation(
        action: AICommandAction,
        pendingConfirmation: CoachPendingConfirmation?
    ) -> CoachEntryReferenceResolution? {
        guard let pendingConfirmation else { return nil }

        switch pendingConfirmation {
        case .food(let draft):
            guard action.type == .editEntry else {
                if action.type == .deleteEntry {
                    return CoachEntryReferenceResolution(
                        outcome: .blocked(
                            message: CoachResponseBuilder.entryReferencePendingNotLogged
                        ),
                        enrichedAction: nil
                    )
                }
                return nil
            }
            guard let foodDraft = action.foodDraft else { return nil }
            let updatedDraft = mergePendingFoodEdit(base: draft, edit: foodDraft)
            return CoachEntryReferenceResolution(
                outcome: .target(
                    linkedEntryId: nil,
                    linkedTimelineEventId: nil,
                    confidence: .high,
                    pendingFoodDraft: updatedDraft
                ),
                enrichedAction: action
            )

        case .edit(let pendingAction, _, _), .delete(let pendingAction, _, _):
            guard pendingAction.linkedEntryId != nil || pendingAction.targetEntrySelector != nil else {
                return nil
            }
            var enriched = action
            enriched.linkedEntryId = pendingAction.linkedEntryId
            enriched.linkedTimelineEventId = pendingAction.linkedTimelineEventId
            enriched.targetEntrySelector = action.targetEntrySelector ?? pendingAction.targetEntrySelector
            return CoachEntryReferenceResolution(
                outcome: .target(
                    linkedEntryId: enriched.linkedEntryId,
                    linkedTimelineEventId: enriched.linkedTimelineEventId,
                    confidence: .high,
                    pendingFoodDraft: nil
                ),
                enrichedAction: enriched
            )

        case .water, .weight, .undo:
            return nil
        }
    }

    // MARK: - Priority: explicit linkedEntryId

    private static func resolveExplicitEntryId(
        _ entryId: UUID,
        action: AICommandAction,
        context: CoachContextPacketV2,
        isUndoFlow: Bool
    ) -> CoachEntryReferenceResolution {
        if isRejectedOrPendingTarget(entryId: entryId, in: context.timeline.recentEvents, isUndoFlow: isUndoFlow) {
            return CoachEntryReferenceResolution(
                outcome: .blocked(message: CoachResponseBuilder.entryReferenceRejectedOrPending),
                enrichedAction: nil
            )
        }

        let events = eligibleFoodTargetEvents(in: context.timeline.recentEvents, isUndoFlow: isUndoFlow)
        let hasConfirmedEvent = events.contains(where: { $0.linkedEntryId == entryId })
        let hasRecentMeal = context.recentMealsStructured.contains(where: { $0.linkedEntryId == entryId })

        guard hasConfirmedEvent || hasRecentMeal || isUndoFlow else {
            return CoachEntryReferenceResolution(
                outcome: .blocked(message: CoachResponseBuilder.entryReferenceDeletedOrMissing),
                enrichedAction: nil
            )
        }

        var enriched = action
        enriched.linkedEntryId = entryId
        enriched.linkedTimelineEventId = linkedTimelineEventId(forEntryId: entryId, in: events)
        return CoachEntryReferenceResolution(
            outcome: .target(
                linkedEntryId: entryId,
                linkedTimelineEventId: enriched.linkedTimelineEventId,
                confidence: .high,
                pendingFoodDraft: nil
            ),
            enrichedAction: enriched
        )
    }

    // MARK: - Priority: recent foodLogged

    private static func resolveMostRecentFoodEvent(
        events: [CoachTimelineContextEvent],
        action: AICommandAction,
        confidence: CoachEntryReferenceConfidence
    ) -> CoachEntryReferenceResolution? {
        guard let event = events.last(where: { $0.type == CoachTimelineEventType.foodLogged.rawValue }),
              let entryId = event.linkedEntryId else {
            return nil
        }

        var enriched = action
        enriched.linkedEntryId = entryId
        enriched.linkedTimelineEventId = event.id
        return CoachEntryReferenceResolution(
            outcome: .target(
                linkedEntryId: entryId,
                linkedTimelineEventId: event.id,
                confidence: confidence,
                pendingFoodDraft: nil
            ),
            enrichedAction: enriched
        )
    }

    // MARK: - Priority: meal type

    private static func resolveMealType(
        _ mealType: MealType,
        events: [CoachTimelineContextEvent],
        meals: [CoachRecentMealContext],
        action: AICommandAction
    ) -> CoachEntryReferenceResolution? {
        let mealTypeRaw = mealType.rawValue.lowercased()
        let typedEvents = events.filter { event in
            guard event.linkedEntryId != nil else { return false }
            return eventMealType(event)?.lowercased() == mealTypeRaw
        }
        let typedMeals = meals.filter { $0.mealType?.lowercased() == mealTypeRaw }

        let candidateEntryIds = uniqueEntryIds(from: typedEvents, meals: typedMeals)
        return resolution(for: candidateEntryIds, events: typedEvents, action: action, uniqueConfidence: .medium)
    }

    // MARK: - Priority: meal name

    private static func resolveMealName(
        selector: String,
        meals: [CoachRecentMealContext],
        events: [CoachTimelineContextEvent],
        action: AICommandAction
    ) -> CoachEntryReferenceResolution? {
        let normalizedSelector = CommandParserUtilities.normalized(selector)
        guard !normalizedSelector.isEmpty else { return nil }

        if matchesAssistantOnlyReference(normalizedSelector, events: events) {
            return CoachEntryReferenceResolution(
                outcome: .blocked(message: CoachResponseBuilder.entryReferenceAssistantOnly),
                enrichedAction: nil
            )
        }

        let matchedMeals = meals.filter { meal in
            let name = CommandParserUtilities.normalized(meal.name)
            guard !name.isEmpty else { return false }
            return normalizedSelector.contains(name) || name.contains(normalizedSelector)
        }

        let matchedEvents = events.filter { event in
            guard let entryId = event.linkedEntryId else { return false }
            let name = eventMealName(event).map(CommandParserUtilities.normalized) ?? ""
            guard !name.isEmpty else { return false }
            return normalizedSelector.contains(name) || name.contains(normalizedSelector)
                || matchedMeals.contains(where: { $0.linkedEntryId == entryId })
        }

        let candidateEntryIds = uniqueEntryIds(from: matchedEvents, meals: matchedMeals)
        return resolution(for: candidateEntryIds, events: matchedEvents, action: action, uniqueConfidence: .medium)
    }

    // MARK: - Priority: demonstrative timeline reference

    private static func resolveDemonstrativeTimelineReference(
        events: [CoachTimelineContextEvent],
        action: AICommandAction
    ) -> CoachEntryReferenceResolution? {
        resolveMostRecentFoodEvent(events: events, action: action, confidence: .medium)
    }

    // MARK: - Candidate aggregation

    private static func resolution(
        for candidateEntryIds: [UUID],
        events: [CoachTimelineContextEvent],
        action: AICommandAction,
        uniqueConfidence: CoachEntryReferenceConfidence
    ) -> CoachEntryReferenceResolution? {
        switch candidateEntryIds.count {
        case 0:
            return nil
        case 1:
            let entryId = candidateEntryIds[0]
            let event = events.last(where: { $0.linkedEntryId == entryId })
            var enriched = action
            enriched.linkedEntryId = entryId
            enriched.linkedTimelineEventId = event?.id
            return CoachEntryReferenceResolution(
                outcome: .target(
                    linkedEntryId: entryId,
                    linkedTimelineEventId: event?.id,
                    confidence: uniqueConfidence,
                    pendingFoodDraft: nil
                ),
                enrichedAction: enriched
            )
        default:
            let labels = candidateEntryIds.compactMap { entryId in
                events.last(where: { $0.linkedEntryId == entryId })?.summary
                    ?? events.last(where: { $0.linkedEntryId == entryId }).flatMap(eventMealName)
            }
            return CoachEntryReferenceResolution(
                outcome: .clarify(
                    message: CoachResponseBuilder.entryReferenceClarification(
                        candidateLabels: labels.isEmpty ? candidateEntryIds.map(\.uuidString) : labels
                    )
                ),
                enrichedAction: nil
            )
        }
    }

    // MARK: - Eligibility helpers

    static func eligibleFoodTargetEvents(
        in events: [CoachTimelineContextEvent],
        isUndoFlow: Bool
    ) -> [CoachTimelineContextEvent] {
        events.filter { event in
            isEligibleFoodTargetEvent(event, isUndoFlow: isUndoFlow)
        }
    }

    static func isEligibleFoodTargetEvent(
        _ event: CoachTimelineContextEvent,
        isUndoFlow: Bool
    ) -> Bool {
        if event.status == CoachTimelineEventStatus.superseded.rawValue
            || event.status == CoachTimelineEventStatus.rejected.rawValue
            || event.status == CoachTimelineEventStatus.failed.rawValue {
            return false
        }

        if event.status == CoachTimelineEventStatus.pending.rawValue {
            return false
        }

        if event.type == CoachTimelineEventType.assistantMessage.rawValue
            || event.type == CoachTimelineEventType.userMessage.rawValue {
            return false
        }

        if event.type == CoachTimelineEventType.foodDeleted.rawValue {
            return isUndoFlow
        }

        if event.type == CoachTimelineEventType.foodRejected.rawValue
            || event.type == CoachTimelineEventType.foodEstimateCreated.rawValue {
            return false
        }

        guard event.status == CoachTimelineEventStatus.confirmed.rawValue else { return false }

        switch event.type {
        case CoachTimelineEventType.foodLogged.rawValue,
             CoachTimelineEventType.foodEdited.rawValue:
            return event.linkedEntryId != nil
        default:
            return false
        }
    }

    private static func eligibleMeals(
        from meals: [CoachRecentMealContext],
        events: [CoachTimelineContextEvent]
    ) -> [CoachRecentMealContext] {
        let deletedEntryIds = Set(
            events
                .filter { $0.type == CoachTimelineEventType.foodDeleted.rawValue }
                .compactMap(\.linkedEntryId)
        )
        return meals.filter { meal in
            guard let entryId = meal.linkedEntryId else { return false }
            return !deletedEntryIds.contains(entryId)
        }
    }

    private static func isRejectedOrPendingTarget(
        entryId: UUID,
        in events: [CoachTimelineContextEvent],
        isUndoFlow: Bool
    ) -> Bool {
        guard !isUndoFlow else { return false }

        for event in events.reversed() where event.linkedEntryId == entryId {
            if event.type == CoachTimelineEventType.foodRejected.rawValue {
                return true
            }
            if event.status == CoachTimelineEventStatus.rejected.rawValue {
                return true
            }
            if event.type == CoachTimelineEventType.foodEstimateCreated.rawValue,
               event.status == CoachTimelineEventStatus.pending.rawValue {
                return true
            }
            if event.type == CoachTimelineEventType.pendingConfirmationCreated.rawValue,
               event.status == CoachTimelineEventStatus.pending.rawValue {
                return true
            }
        }
        return false
    }

    private static func matchesAssistantOnlyReference(
        _ normalizedSelector: String,
        events: [CoachTimelineContextEvent]
    ) -> Bool {
        guard !normalizedSelector.isEmpty else { return false }
        let assistantMessages = events
            .filter { $0.type == CoachTimelineEventType.assistantMessage.rawValue }
            .map { CommandParserUtilities.normalized($0.summary) }
            .filter { !$0.isEmpty }

        guard !assistantMessages.isEmpty else { return false }
        let referencesFood = MealType.allCases.contains { normalizedSelector.contains($0.rawValue.lowercased()) }
            || demonstrativeTokens.contains(where: { normalizedSelector.contains($0) })
        guard !referencesFood else { return false }

        return assistantMessages.contains { normalizedSelector == $0 || normalizedSelector.contains($0) }
    }

    // MARK: - Parsing helpers

    private static func normalizedSelector(_ selector: String?) -> String {
        CommandParserUtilities.normalized(selector ?? "")
    }

    private static func referencesDemonstrative(_ selector: String) -> Bool {
        demonstrativeTokens.contains { selector.contains($0) }
    }

    private static func mealTypeHint(from action: AICommandAction, selector: String) -> MealType? {
        if let mealType = action.foodDraft?.mealType {
            return mealType
        }
        for mealType in MealType.allCases where selector.contains(mealType.rawValue.lowercased()) {
            return mealType
        }
        return nil
    }

    private static func eventMealType(_ event: CoachTimelineContextEvent) -> String? {
        event.compactPayload?["mealType"]
    }

    private static func eventMealName(_ event: CoachTimelineContextEvent) -> String? {
        event.compactPayload?["name"]
    }

    private static func uniqueEntryIds(
        from events: [CoachTimelineContextEvent],
        meals: [CoachRecentMealContext]
    ) -> [UUID] {
        var ids: [UUID] = []
        for event in events {
            if let entryId = event.linkedEntryId, !ids.contains(entryId) {
                ids.append(entryId)
            }
        }
        for meal in meals {
            if let entryId = meal.linkedEntryId, !ids.contains(entryId) {
                ids.append(entryId)
            }
        }
        return ids
    }

    private static func mergePendingFoodEdit(
        base: AIFoodConfirmationDraft,
        edit: FoodDraft
    ) -> AIFoodConfirmationDraft {
        var updated = base
        var meal = base.primaryMealDraft

        if !edit.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            meal = FoodLogDraftNutritionCompleter.mergeExplicit(edit, into: meal, hintText: base.originalText)
        } else {
            meal = FoodLogDraftNutritionCompleter.mergeExplicit(
                FoodDraft(
                    mealType: edit.mealType,
                    name: meal.displayName,
                    quantity: edit.quantity ?? meal.legacyQuantity,
                    unit: edit.unit ?? meal.legacyUnit,
                    calories: edit.calories,
                    protein: edit.protein,
                    carbs: edit.carbs,
                    fat: edit.fat,
                    fiber: edit.fiber,
                    sodium: edit.sodium,
                    source: edit.source,
                    confidence: edit.confidence,
                    imageUrl: edit.imageUrl,
                    notes: edit.notes
                ),
                into: meal,
                hintText: base.originalText
            )
        }

        updated.mealDraft = FoodLogDraftNutritionCompleter.sanitize(meal, hintText: base.originalText)
        return updated
    }
}
