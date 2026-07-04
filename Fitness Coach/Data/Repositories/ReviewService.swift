//
//  ReviewService.swift
//  Fitness Coach
//
//  FitPilot AI — Owns daily review generation and persistence.
//
//  ReviewService builds deterministic summaries, asks AI only for narrative
//  text, then persists DailyReview through SwiftData. It does not call LLMClient
//  directly and does not trust AI for final numbers.
//
//  Write ownership: user-triggered generation goes through FitnessActionCenter
//  .generateDailyReview. Cloud merge writes go through AccountSyncPuller.
//  SSOT: Docs/Architecture/SourceOfTruthMap.md §3.
//

import Foundation
import SwiftData

@MainActor
final class ReviewService {

    private let store: SwiftDataStore
    private let dailyLogService: DailyLogService
    private let foodLogService: FoodLogService
    private let waterLogService: WaterLogService
    private let weightLogService: WeightLogService
    private let healthActivityQuery: HealthActivityQueryService
    private let userProfileService: UserProfileService
    private let aiService: AIServiceProtocol
    private let mutationTracker: AccountLocalMutationTracker?

    init(
        store: SwiftDataStore,
        dailyLogService: DailyLogService,
        foodLogService: FoodLogService,
        waterLogService: WaterLogService,
        weightLogService: WeightLogService,
        healthActivityQuery: HealthActivityQueryService,
        userProfileService: UserProfileService,
        aiService: AIServiceProtocol,
        mutationTracker: AccountLocalMutationTracker? = nil
    ) {
        self.store = store
        self.dailyLogService = dailyLogService
        self.foodLogService = foodLogService
        self.waterLogService = waterLogService
        self.weightLogService = weightLogService
        self.healthActivityQuery = healthActivityQuery
        self.userProfileService = userProfileService
        self.aiService = aiService
        self.mutationTracker = mutationTracker
    }

    // MARK: Read

    func getDailyReview(for date: Date) throws -> DailyReview? {
        guard let dailyLog = try dailyLogService.dailyLogEntity(for: date) else {
            return nil
        }
        guard let entity = try dailyReviewEntity(dailyLogId: dailyLog.id),
              AccountDataSyncReadFilter.isVisible(entity) else {
            return nil
        }
        return entity.toModel()
    }

    // MARK: Generate

    func generateDailyReview(
        for date: Date,
        forceRegenerate: Bool = false
    ) async throws -> DailyReview {
        let dailyLogEntity = try dailyLogService.getOrCreateLogEntity(for: date)

        if !forceRegenerate, let existing = try dailyReviewEntity(dailyLogId: dailyLogEntity.id),
           AccountDataSyncReadFilter.isVisible(existing) {
            return existing.toModel()
        }

        let dailyLog = try dailyLogService.recalculateDailyTotals(for: dailyLogEntity.date)
        let summary = try await buildSummary(for: dailyLog)
        let aiInput = DailyReviewFormatter.dailyReviewAIInput(from: summary)
        let aiContext = makeReviewContext(from: summary)

        let aiResponse = try? await aiService.generateDailyReviewText(
            input: aiInput,
            context: aiContext
        )

        let review = makeReview(
            dailyLog: dailyLog,
            summary: summary,
            aiResponse: aiResponse
        )

        return try persist(review, dailyLogEntity: dailyLogEntity)
    }

    // MARK: Summary

    private func buildSummary(for dailyLog: DailyLog) async throws -> DailyReviewSummary {
        let foodEntries = try foodLogService.getFoodEntries(for: dailyLog.date)
        let waterEntries = try waterLogService.getWaterEntries(for: dailyLog.date)
        let training = await healthActivityQuery.dailyTrainingActivity(on: dailyLog.date)
        let latestWeight = try weightLogService.getLatestWeight()
        let weightEntry = try weightEntry(for: dailyLog.date)

        return DailyReviewSummaryBuilder.build(
            dailyLog: dailyLog,
            foodEntries: foodEntries,
            waterEntries: waterEntries,
            weightEntry: weightEntry,
            latestWeightEntry: latestWeight,
            training: training
        )
    }

    private func weightEntry(for date: Date) throws -> WeightEntry? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }
        return try weightLogService
            .getWeightEntries(from: startOfDay, to: nextDay)
            .last { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }
    }

    // MARK: Review Creation

    private func makeReview(
        dailyLog: DailyLog,
        summary: DailyReviewSummary,
        aiResponse: AICoachResponse?
    ) -> DailyReview {
        DailyReview(
            id: UUID(),
            dailyLogId: dailyLog.id,
            summaryText: aiResponse?.message ?? DailyReviewFormatter.fallbackSummaryText(),
            caloriesSummary: DailyReviewFormatter.caloriesSummary(from: summary),
            proteinSummary: DailyReviewFormatter.proteinSummary(from: summary),
            hydrationSummary: DailyReviewFormatter.hydrationSummary(from: summary),
            workoutSummary: DailyReviewFormatter.workoutSummary(from: summary),
            weightSummary: DailyReviewFormatter.weightSummary(from: summary),
            tomorrowRecommendation: DailyReviewFormatter.tomorrowRecommendation(from: summary),
            createdAt: Date()
        )
    }

    // MARK: Persistence

    private func persist(
        _ review: DailyReview,
        dailyLogEntity: DailyLogEntity
    ) throws -> DailyReview {
        if let existing = try dailyReviewEntity(dailyLogId: dailyLogEntity.id) {
            apply(review, to: existing)
            existing.dailyLog = dailyLogEntity
            dailyLogEntity.dailyReview = existing
            dailyLogEntity.dailyReviewId = existing.id
            try save()
            try trackReviewUpsert(existing, dailyLog: dailyLogEntity)
            return existing.toModel()
        }

        let entity = DailyReviewEntity(model: review)
        entity.dailyLog = dailyLogEntity
        dailyLogEntity.dailyReview = entity
        dailyLogEntity.dailyReviewId = review.id
        try store.insert(entity)
        try save()
        try trackReviewUpsert(entity, dailyLog: dailyLogEntity)
        return entity.toModel()
    }

    private func trackReviewUpsert(_ entity: DailyReviewEntity, dailyLog: DailyLogEntity) throws {
        guard let mutationTracker else { return }
        let mutationGroupId = mutationTracker.makeMutationGroupId()
        try mutationTracker.trackDailyReviewUpsert(entity, dailyLog: dailyLog, mutationGroupId: mutationGroupId)
        try save()
    }

    private func dailyReviewEntity(dailyLogId: UUID) throws -> DailyReviewEntity? {
        var descriptor = FetchDescriptor<DailyReviewEntity>(
            predicate: #Predicate { $0.dailyLogId == dailyLogId }
        )
        descriptor.fetchLimit = 1
        return try store.fetch(descriptor).first
    }

    private func apply(_ review: DailyReview, to entity: DailyReviewEntity) {
        entity.dailyLogId = review.dailyLogId
        entity.summaryText = review.summaryText
        entity.caloriesSummary = review.caloriesSummary
        entity.proteinSummary = review.proteinSummary
        entity.hydrationSummary = review.hydrationSummary
        entity.workoutSummary = review.workoutSummary
        entity.weightSummary = review.weightSummary
        entity.tomorrowRecommendation = review.tomorrowRecommendation
        entity.createdAt = review.createdAt
    }

    private func save() throws {
        do {
            try store.save()
        } catch {
            throw ServiceError.persistenceFailed("Could not save the daily review.")
        }
    }

    // MARK: AI Context

    private func makeReviewContext(from summary: DailyReviewSummary) -> CoachContextPacketV2 {
        let profile = (try? userProfileService.getCurrentProfile()).map(CoachContextPacketV2.reviewProfile)
        return CoachContextPacketV2.reviewContext(from: summary, profile: profile)
    }
}
