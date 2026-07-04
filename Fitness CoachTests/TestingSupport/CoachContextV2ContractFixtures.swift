//
//  CoachContextV2ContractFixtures.swift
//  Fitness CoachTests
//
//  Swift-built CoachContextPacketV2 fixtures aligned with backend JSON contracts.
//

import Foundation
@testable import Fitness_Coach

enum CoachContextV2ContractFixtures {

    enum IDs {
        static let linkedEntry = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        static let timelineEvent = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        static let chatMessage = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
    }

    enum Dates {
        static let reference = ISO8601DateFormatter.contractReferenceDate
        static let workoutStart = ISO8601DateFormatter.contractDate(from: "2026-07-03T08:00:00.000Z")!
        static let workoutEnd = ISO8601DateFormatter.contractDate(from: "2026-07-03T08:35:00.000Z")!
        static let mealLoggedAt = ISO8601DateFormatter.contractDate(from: "2026-07-03T10:00:00.000Z")!
        static let chatTimestamp = ISO8601DateFormatter.contractDate(from: "2026-07-03T11:30:00.000Z")!
        static let commonFoodLastLogged = ISO8601DateFormatter.contractDate(from: "2026-07-02T08:00:00.000Z")!
    }

    static var contractMeta: CoachContextMeta {
        CoachContextMeta(
            generatedAt: Dates.reference,
            timezoneIdentifier: "UTC",
            localDate: "2026-07-03",
            localTime: "12:00",
            appVersion: nil
        )
    }

    static var minimal: CoachContextPacketV2 {
        CoachContextPacketV2(
            meta: contractMeta,
            generationMode: .live
        )
    }

    static var rich: CoachContextPacketV2 {
        CoachContextPacketV2(
            meta: CoachContextMeta(
                generatedAt: Dates.reference,
                timezoneIdentifier: "UTC",
                localDate: "2026-07-03",
                localTime: "12:00",
                appVersion: "2.4.1"
            ),
            profile: CoachUserProfileContext(
                age: 32,
                sex: .female,
                heightCm: 168,
                currentWeightKg: 68,
                goalWeightKg: 64,
                activityLevel: .moderatelyActive,
                trainingFrequencyPerWeek: 4,
                goalType: "Lose Fat"
            ),
            today: CoachContextTodayPacket(
                targets: CoachTodayTargetsContext(
                    calorieTarget: 2_000,
                    proteinTarget: 140,
                    carbsTarget: 180,
                    fatTarget: 65,
                    waterTargetMl: 2_500
                ),
                nutrition: CoachTodayNutritionContext(
                    caloriesConsumed: 1_200,
                    caloriesRemaining: 800,
                    proteinConsumed: 80,
                    proteinRemaining: 60,
                    carbsConsumed: 120,
                    carbsRemaining: 60,
                    fatConsumed: 40,
                    fatRemaining: 25
                ),
                hydration: CoachTodayHydrationContext(
                    waterConsumedMl: 1_200,
                    waterRemainingMl: 1_300
                ),
                steps: CoachContextSourcedInt(
                    value: 8_000,
                    source: "healthKit",
                    confidence: .medium
                )
            ),
            training: CoachTrainingContext(
                workoutsToday: 1,
                workouts: [
                    CoachContextWorkoutSummary(
                        title: "Run",
                        type: "running",
                        start: Dates.workoutStart,
                        end: Dates.workoutEnd,
                        durationMinutes: 35,
                        activeEnergyKcal: 320,
                        source: "healthKit",
                        confidence: .medium
                    )
                ],
                trainingLoad: "normal",
                recoveryStatus: "moderate",
                readiness: "moderate"
            ),
            timeline: CoachContextTimelinePacket(
                recentEvents: [
                    CoachTimelineContextEvent(
                        id: IDs.timelineEvent,
                        timestamp: Dates.mealLoggedAt,
                        type: CoachTimelineEventType.foodLogged.rawValue,
                        source: CoachTimelineEventSource.coachUI.rawValue,
                        status: CoachTimelineEventStatus.confirmed.rawValue,
                        summary: "Logged Salad",
                        compactPayload: ["name": "Salad", "kcal": "420"],
                        confidence: .high,
                        linkedEntryId: IDs.linkedEntry
                    )
                ]
            ),
            recentChatMessages: [
                CoachChatMessageContext(
                    id: IDs.chatMessage,
                    role: "user",
                    text: "How am I doing today?",
                    timestamp: Dates.chatTimestamp,
                    hasPhotoAttachment: false
                )
            ],
            currentUserMessage: "Should I eat more protein?",
            recentMealsStructured: [
                CoachRecentMealContext(
                    name: "Salad",
                    quantity: 1,
                    unit: "bowl",
                    calories: 420,
                    proteinGrams: 28,
                    carbsGrams: 30,
                    fatGrams: 14,
                    loggedAt: Dates.mealLoggedAt,
                    localDate: "2026-07-03",
                    source: FoodEntrySource.manual.rawValue,
                    confidence: .high,
                    linkedEntryId: IDs.linkedEntry
                )
            ],
            commonFoods: [
                CoachCommonFoodContext(
                    name: "Oatmeal",
                    logCount: 12,
                    lastLoggedAt: Dates.commonFoodLastLogged,
                    typicalCalories: 300
                )
            ],
            missingData: CoachMissingDataContext(sleepMissing: true),
            assumptions: [
                CoachAssumptionContext(
                    key: "steps_source",
                    detail: "Steps sourced from Apple Health when authorized.",
                    confidence: .medium
                )
            ],
            generationMode: .live,
            sourceAttribution: CoachContextSourceAttribution(
                generationMode: .live,
                timelineEventCount: 1,
                recentMealCount: 1,
                commonFoodCount: 1,
                healthIntelligenceIncluded: false,
                sources: ["swiftData", "healthKit"]
            )
        )
    }

    static var degraded: CoachContextPacketV2 {
        CoachContextPacketV2(
            meta: contractMeta,
            missingData: CoachMissingDataContext(
                stepsMissing: true,
                workoutPermissionDeniedOrUnavailable: true,
                noRecentMeals: true,
                noTimelineHistory: true,
                healthKitUnavailable: true
            ),
            generationMode: .degraded
        )
    }

    static let tinyPNGBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQRV42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

    static var analyzeMealImageRequest: AIMealImageAnalysisRequest {
        AIMealImageAnalysisRequest(
            message: "Lunch photo",
            context: rich,
            image: AIMealImagePayload(
                mimeType: "image/png",
                base64: tinyPNGBase64
            )
        )
    }
}

private extension ISO8601DateFormatter {

    static let contractReferenceDate: Date = {
        contractDate(from: "2026-07-03T12:00:00.000Z")!
    }()

    static func contractDate(from string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}
