//
//  CoachContextPacketV2DebugRedactor.swift
//  Fitness Coach
//
//  Forma — DEBUG-only redacted JSON export for Coach context inspection.
//

#if DEBUG
import Foundation

enum CoachContextPacketV2DebugRedactor {

    private static let secretPatterns: [NSRegularExpression] = {
        let rawPatterns = [
            #"(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*"#,
            #"eyJ[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+"#,
            #"(?i)(api[_-]?key|token|secret|password)\s*[:=]\s*\S+"#,
            #"[A-Za-z0-9+/]{120,}={0,2}"#
        ]
        return rawPatterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    static func redactedJSONString(from packet: CoachContextPacketV2) throws -> String {
        let sanitized = sanitize(packet)
        let encoder = CoachContextPacketV2.makeJSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(sanitized)
        var json = String(data: data, encoding: .utf8) ?? "{}"
        json = redactSecrets(in: json)
        return json
    }

    static func sanitize(_ packet: CoachContextPacketV2) -> CoachContextPacketV2 {
        var copy = packet.clampedForTransport()

        copy.recentChatMessages = copy.recentChatMessages.map { message in
            var sanitized = message
            sanitized.text = redactSecrets(in: truncate(message.text, maxLength: 120))
            return sanitized
        }

        if var current = copy.currentUserMessage {
            current = redactSecrets(in: truncate(current, maxLength: 120))
            copy.currentUserMessage = current
        }

        copy.timeline.recentEvents = copy.timeline.recentEvents.map { event in
            var sanitized = event.clampedForTransport()
            sanitized.summary = redactSecrets(in: sanitized.summary)
            if let payload = sanitized.compactPayload {
                sanitized.compactPayload = Dictionary(
                    uniqueKeysWithValues: payload.map { key, value in
                        (key, redactSecrets(in: truncate(value, maxLength: 80)))
                    }
                )
            }
            return sanitized
        }

        copy.recentMealsStructured = copy.recentMealsStructured.map { meal in
            var sanitized = meal
            sanitized.name = redactSecrets(in: truncate(meal.name, maxLength: 80))
            return sanitized
        }

        if var profile = copy.profile {
            profile.currentWeightKg = profile.currentWeightKg.map { ($0 * 10).rounded() / 10 }
            profile.goalWeightKg = profile.goalWeightKg.map { ($0 * 10).rounded() / 10 }
            copy.profile = profile
        }

        return copy
    }

    static func redactSecrets(in text: String) -> String {
        var result = text
        for pattern in secretPatterns {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = pattern.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "[REDACTED]"
            )
        }
        return result
    }

    private static func truncate(_ value: String, maxLength: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<index]) + "…"
    }
}
#endif
