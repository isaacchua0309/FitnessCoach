//
//  LogRedactor.swift
//  Fitness Coach
//
//  Forma — Shared privacy-safe logging redaction for Release and DEBUG diagnostics.
//
//  Registry: Docs/Architecture/LoggingAndPrivacyContract.md
//

import CryptoKit
import Foundation
import OSLog

enum LogRedactor {

    static let jsonRedactedPlaceholder = "<redacted>"
    static let secretRedactedPlaceholder = "[REDACTED]"

    // MARK: - Identifiers

    /// Short stable hash for correlating logs without logging full Firebase UIDs.
    static func hashedUID(_ uid: String) -> String {
        let digest = SHA256.hash(data: Data(uid.utf8))
        return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
    }

    /// Suffix-only UID for bootstrap/auth traces.
    static func redactUID(_ uid: String) -> String {
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 6 else { return "***" }
        return "***\(trimmed.suffix(6))"
    }

    /// Prefix UID for deletion coordinator traces (legacy-safe; prefer `hashedUID`).
    static func privacySafeUIDPrefix(_ uid: String) -> String {
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return "uid_redacted" }
        return String(trimmed.prefix(8)) + "…"
    }

    // MARK: - Text

    static func truncate(_ value: String, maxLength: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<index]) + "…"
    }

    /// Redacts bearer tokens, JWTs, API keys, long base64 blobs, and email addresses in free text.
    static func redactSecrets(in text: String) -> String {
        var result = text
        for pattern in secretPatterns {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = pattern.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: secretRedactedPlaceholder
            )
        }
        result = emailPattern.stringByReplacingMatches(
            in: result,
            options: [],
            range: NSRange(result.startIndex..<result.endIndex, in: result),
            withTemplate: secretRedactedPlaceholder
        )
        return result
    }

    // MARK: - JSON snippets

    /// Redacts sensitive JSON fields in HTTP/AI request and response snippets.
    static func redactSensitiveJSONFields(_ raw: String) -> String {
        var sanitized = raw

        let replacements: [(String, String)] = [
            (#"Bearer\s+\S+"#, "Bearer \(jsonRedactedPlaceholder)"),
            (#""Authorization"\s*:\s*"[^"]*""#, "\"Authorization\":\"\(jsonRedactedPlaceholder)\""),
            (#""base64"\s*:\s*"[^"]*""#, "\"base64\":\"\(jsonRedactedPlaceholder)\""),
            (#""imageJPEGBase64"\s*:\s*"[^"]*""#, "\"imageJPEGBase64\":\"\(jsonRedactedPlaceholder)\""),
            (#""message"\s*:\s*"[^"]*""#, "\"message\":\"\(jsonRedactedPlaceholder)\""),
            (#""clarification"\s*:\s*"[^"]*""#, "\"clarification\":\"\(jsonRedactedPlaceholder)\""),
            (#""text"\s*:\s*"[^"]*""#, "\"text\":\"\(jsonRedactedPlaceholder)\""),
            (#""name"\s*:\s*"[^"]*""#, "\"name\":\"\(jsonRedactedPlaceholder)\""),
            (#""summary"\s*:\s*"[^"]*""#, "\"summary\":\"\(jsonRedactedPlaceholder)\""),
            (#""review"\s*:\s*"[^"]*""#, "\"review\":\"\(jsonRedactedPlaceholder)\""),
            (#""userMessage"\s*:\s*"[^"]*""#, "\"userMessage\":\"\(jsonRedactedPlaceholder)\""),
            (#""email"\s*:\s*"[^"]*""#, "\"email\":\"\(jsonRedactedPlaceholder)\""),
            (#""token"\s*:\s*"[^"]*""#, "\"token\":\"\(jsonRedactedPlaceholder)\""),
            (#""password"\s*:\s*"[^"]*""#, "\"password\":\"\(jsonRedactedPlaceholder)\""),
            (#""payload"\s*:\s*\{[\s\S]*?\}(?=,\s*"|\s*\})"#, "\"payload\":\"\(jsonRedactedPlaceholder)\""),
            (#""context"\s*:\s*\{[\s\S]*?\}(?=,\s*"|\s*\})"#, "\"context\":\"\(jsonRedactedPlaceholder)\""),
            (#""document"\s*:\s*\{[\s\S]*?\}(?=,\s*"|\s*\})"#, "\"document\":\"\(jsonRedactedPlaceholder)\""),
        ]

        for (pattern, template) in replacements {
            sanitized = sanitized.replacingOccurrences(
                of: pattern,
                with: template,
                options: .regularExpression
            )
        }

        return sanitized
    }

    // MARK: - Structured fields

    struct SanitizeOptions: Sendable {
        var allowedKeys: Set<String> = []
        var maxValueLength: Int = 64
        var hashUIDKeys: Bool = true

        static let `default` = SanitizeOptions()
    }

    static func sanitizeLogFields(
        _ fields: [String: String],
        options: SanitizeOptions = .default
    ) -> [String: String] {
        var result: [String: String] = [:]
        result.reserveCapacity(fields.count)

        for (key, value) in fields {
            let lowered = key.lowercased()

            if options.allowedKeys.contains(lowered) {
                result[key] = truncateValue(value, maxLength: options.maxValueLength)
                continue
            }

            if lowered == "uid", options.hashUIDKeys {
                result["uidHash"] = hashedUID(value)
                continue
            }

            if lowered.contains("uid"), lowered != "uidhash" {
                continue
            }

            if isSensitiveFieldKey(lowered, allowedKeys: options.allowedKeys) {
                continue
            }

            if isSensitiveFieldValue(value) {
                continue
            }

            result[key] = truncateValue(value, maxLength: options.maxValueLength)
        }

        return result
    }

    static func isSensitiveFieldKey(_ key: String, allowedKeys: Set<String> = []) -> Bool {
        if allowedKeys.contains(key) {
            return false
        }

        let aggregatePrefixes = ["pulled", "uploaded", "sync", "restore", "merge"]
        if aggregatePrefixes.contains(where: { key.hasPrefix($0) }) {
            return false
        }

        let aggregateSuffixes = [
            "restored", "fetched", "mutations", "inserted", "updated",
            "deleted", "conflicts", "failed", "count", "durationms", "traceid"
        ]
        if aggregateSuffixes.contains(where: { key.hasSuffix($0) }) {
            return false
        }

        let blocked = [
            "name", "calorie", "protein", "carb", "fat", "fiber", "sodium",
            "review", "summary", "message", "note", "image", "base64",
            "coach", "text", "quantity", "amount", "payload", "document", "healthkit",
            "profile", "email", "token", "password", "bearer", "authorization", "secret"
        ]
        return blocked.contains { key.contains($0) }
    }

    static func isSensitiveFieldValue(_ value: String) -> Bool {
        let lowered = value.lowercased()
        if lowered.contains("bearer ") || lowered.contains("eyj") {
            return true
        }
        if lowered.contains("firebase") || lowered.contains("users/") {
            return true
        }
        if emailPattern.firstMatch(
            in: value,
            options: [],
            range: NSRange(value.startIndex..<value.endIndex, in: value)
        ) != nil {
            return true
        }
        if value.count > 120 {
            return true
        }
        return false
    }

    // MARK: - Buckets (production-safe aggregates)

    static func calorieBucket(_ calories: Int) -> String {
        switch calories {
        case ..<0: return "invalid"
        case 0: return "0"
        case 1..<200: return "1-199"
        case 200..<500: return "200-499"
        case 500..<800: return "500-799"
        case 800..<1200: return "800-1199"
        default: return "1200+"
        }
    }

    static func weightBucketKg(_ kilograms: Double) -> String {
        switch kilograms {
        case ..<40: return "<40kg"
        case 40..<60: return "40-59kg"
        case 60..<80: return "60-79kg"
        case 80..<100: return "80-99kg"
        case 100..<120: return "100-119kg"
        default: return "120kg+"
        }
    }

    // MARK: - Errors

    static func safeErrorFields(from error: Error, includeDescription: Bool) -> [String: String] {
        let nsError = error as NSError
        var fields: [String: String] = [:]
        if !nsError.domain.isEmpty {
            fields["errorDomain"] = nsError.domain
            fields["errorCode"] = String(nsError.code)
        }
        if includeDescription {
            let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            if !description.isEmpty {
                fields["errorDescription"] = truncate(redactSecrets(in: description), maxLength: 120)
            }
        }
        return fields
    }

    // MARK: - Formatting

    static func formatLine(message: String, fields: [String: String]) -> String {
        guard !fields.isEmpty else { return message }
        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        return "\(message) \(fieldLine)"
    }

    static func emitOSLogTrace(
        prefix: String,
        logger: Logger,
        message: String,
        fields: [String: String],
        osLogType: OSLogType = .info
    ) {
        let sanitized = sanitizeLogFields(fields)
        let fieldLine = sanitized
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let line = fieldLine.isEmpty
            ? "[\(prefix)] \(message)"
            : "[\(prefix)] \(message) \(fieldLine)"
        logger.log(level: osLogType, "\(line, privacy: .public)")
    }

    // MARK: - Private

    private static let secretPatterns: [NSRegularExpression] = {
        let rawPatterns = [
            #"(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*"#,
            #"eyJ[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+"#,
            #"(?i)(api[_-]?key|token|secret|password)\s*[:=]\s*\S+"#,
            #"[A-Za-z0-9+/]{120,}={0,2}"#
        ]
        return rawPatterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private static let emailPattern: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: [.caseInsensitive])
    }()

    private static func truncateValue(_ value: String, maxLength: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        return String(trimmed.prefix(maxLength))
    }
}
