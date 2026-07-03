//
//  CoachAIRequestContextLogging.swift
//  Fitness Coach
//
//  Redacted logging helpers for Coach AI gateway requests carrying v2 context.
//

import Foundation

protocol CoachAIRequestContextLogging {
    var coachContextPacketForLogging: CoachContextPacketV2? { get }
}

extension AICoachIntentClassificationRequest: CoachAIRequestContextLogging {
    var coachContextPacketForLogging: CoachContextPacketV2? { context }
}

extension AIFoodEstimateRequest: CoachAIRequestContextLogging {
    var coachContextPacketForLogging: CoachContextPacketV2? { context }
}

extension AIMealAdviceRequest: CoachAIRequestContextLogging {
    var coachContextPacketForLogging: CoachContextPacketV2? { context }
}

extension AINutritionEstimateRequest: CoachAIRequestContextLogging {
    var coachContextPacketForLogging: CoachContextPacketV2? { context }
}

extension AINutritionComparisonRequest: CoachAIRequestContextLogging {
    var coachContextPacketForLogging: CoachContextPacketV2? { context }
}

extension AIDailyReviewRequest: CoachAIRequestContextLogging {
    var coachContextPacketForLogging: CoachContextPacketV2? { context }
}

extension AIEditDeleteParseRequest: CoachAIRequestContextLogging {
    var coachContextPacketForLogging: CoachContextPacketV2? { context }
}

extension AIMultiActionParseRequest: CoachAIRequestContextLogging {
    var coachContextPacketForLogging: CoachContextPacketV2? { context }
}

extension AIMealImageAnalysisRequest: CoachAIRequestContextLogging {
    var coachContextPacketForLogging: CoachContextPacketV2? { context }
}

enum CoachAIRequestLogFormatter {

    static func redactedContextFields<Body>(from body: Body) -> [String: String] {
        guard let carrier = body as? CoachAIRequestContextLogging,
              let packet = carrier.coachContextPacketForLogging else {
            return [:]
        }
        return [
            "context": packet.redactedDebugDescription(),
            "contextSchema": String(packet.meta.schemaVersion),
            "timelineEvents": String(packet.timeline.recentEvents.count)
        ]
    }
}
