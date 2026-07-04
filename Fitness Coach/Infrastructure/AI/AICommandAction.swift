//
//  AICommandAction.swift
//  Fitness Coach
//
//  FitPilot AI — A single structured action proposed by the AI boundary.
//
//  This uses a struct representation (instead of an enum with associated
//  values) so it decodes cleanly from JSON. Drafts are proposals only; they are
//  validated and executed by services elsewhere, never by the AI layer.
//

import Foundation

enum AICommandActionType: String, Codable, Equatable, Sendable {
    case logFood
    case logWater
    case logWeight
    case logWorkout
    case startNewDay
    case mealAdvice
    case status
    case dailyReview
    case editEntry
    case deleteEntry
    case undo
}

struct AICommandAction: Codable, Equatable, Sendable {
    var type: AICommandActionType
    var foodDraft: FoodDraft?
    var waterDraft: WaterDraft?
    var weightDraft: WeightDraft?
    var workoutDraft: WorkoutDraft?
    var startNewDayWeightKg: Double?
    var adviceQuestion: String?
    var targetEntrySelector: String?
    /// Resolved food-entry id (from backend selector UUID or context meals).
    var linkedEntryId: UUID?
    /// Confirmed timeline event tied to `linkedEntryId` when known.
    var linkedTimelineEventId: UUID?

    init(
        type: AICommandActionType,
        foodDraft: FoodDraft? = nil,
        waterDraft: WaterDraft? = nil,
        weightDraft: WeightDraft? = nil,
        workoutDraft: WorkoutDraft? = nil,
        startNewDayWeightKg: Double? = nil,
        adviceQuestion: String? = nil,
        targetEntrySelector: String? = nil,
        linkedEntryId: UUID? = nil,
        linkedTimelineEventId: UUID? = nil
    ) {
        self.type = type
        self.foodDraft = foodDraft
        self.waterDraft = waterDraft
        self.weightDraft = weightDraft
        self.workoutDraft = workoutDraft
        self.startNewDayWeightKg = startNewDayWeightKg
        self.adviceQuestion = adviceQuestion
        self.targetEntrySelector = targetEntrySelector
        self.linkedEntryId = linkedEntryId
        self.linkedTimelineEventId = linkedTimelineEventId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(AICommandActionType.self, forKey: .type)
        foodDraft = try container.decodeIfPresent(FoodDraft.self, forKey: .foodDraft)
        waterDraft = try container.decodeIfPresent(WaterDraft.self, forKey: .waterDraft)
        weightDraft = try container.decodeIfPresent(WeightDraft.self, forKey: .weightDraft)
        workoutDraft = try container.decodeIfPresent(WorkoutDraft.self, forKey: .workoutDraft)
        startNewDayWeightKg = try container.decodeIfPresent(Double.self, forKey: .startNewDayWeightKg)
        adviceQuestion = try container.decodeIfPresent(String.self, forKey: .adviceQuestion)
        targetEntrySelector = try container.decodeIfPresent(String.self, forKey: .targetEntrySelector)
        linkedEntryId = try container.decodeIfPresent(UUID.self, forKey: .linkedEntryId)
            ?? CoachEntryReferenceResolver.linkedEntryId(fromSelector: targetEntrySelector)
        linkedTimelineEventId = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(foodDraft, forKey: .foodDraft)
        try container.encodeIfPresent(waterDraft, forKey: .waterDraft)
        try container.encodeIfPresent(weightDraft, forKey: .weightDraft)
        try container.encodeIfPresent(workoutDraft, forKey: .workoutDraft)
        try container.encodeIfPresent(startNewDayWeightKg, forKey: .startNewDayWeightKg)
        try container.encodeIfPresent(adviceQuestion, forKey: .adviceQuestion)
        try container.encodeIfPresent(targetEntrySelector, forKey: .targetEntrySelector)
        try container.encodeIfPresent(linkedEntryId, forKey: .linkedEntryId)
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case foodDraft
        case waterDraft
        case weightDraft
        case workoutDraft
        case startNewDayWeightKg
        case adviceQuestion
        case targetEntrySelector
        case linkedEntryId
    }
}
