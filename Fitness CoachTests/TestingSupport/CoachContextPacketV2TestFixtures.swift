//
//  CoachContextPacketV2TestFixtures.swift
//  Fitness CoachTests
//
//  Shared CoachContextPacketV2 fixtures for routing and AI service tests.
//

import Foundation
@testable import Fitness_Coach

enum CoachContextPacketV2TestFixtures {

    static let referenceDate = Date(timeIntervalSince1970: 0)

    static var minimal: CoachContextPacketV2 {
        CoachContextPacketV2(
            meta: CoachContextMeta(
                generatedAt: referenceDate,
                timezoneIdentifier: "UTC",
                localDate: "1970-01-01",
                localTime: "00:00"
            ),
            today: CoachContextTodayPacket(
                targets: CoachTodayTargetsContext(
                    calorieTarget: 2_000,
                    proteinTarget: 150,
                    carbsTarget: 200,
                    fatTarget: 65,
                    waterTargetMl: 2_500
                ),
                nutrition: CoachTodayNutritionContext(
                    caloriesConsumed: 1_000,
                    caloriesRemaining: 1_000,
                    proteinConsumed: 80,
                    proteinRemaining: 70,
                    carbsConsumed: 100,
                    carbsRemaining: 100,
                    fatConsumed: 30,
                    fatRemaining: 35
                ),
                hydration: CoachTodayHydrationContext(
                    waterConsumedMl: 1_000,
                    waterRemainingMl: 1_500
                )
            ),
            training: CoachTrainingContext(workoutsToday: 0)
        )
    }

    static func withRecentMessages(_ messages: [CoachChatMessageContext]) -> CoachContextPacketV2 {
        var packet = minimal
        packet.recentChatMessages = messages
        return packet
    }

    static func withHealthIntelligence(
        _ healthIntelligence: CoachHealthIntelligenceContext,
        workoutsToday: Int = 1
    ) -> CoachContextPacketV2 {
        var packet = minimal
        packet.healthIntelligence = healthIntelligence
        packet.training = CoachTrainingContext(workoutsToday: workoutsToday)
        return packet
    }
}

extension CoachContextPacketV2 {
    static var test: CoachContextPacketV2 { CoachContextPacketV2TestFixtures.minimal }
}
