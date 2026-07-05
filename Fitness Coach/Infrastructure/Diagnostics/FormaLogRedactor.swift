//
//  FormaLogRedactor.swift
//  Fitness Coach
//
//  Forma — Centralized, deterministic log redaction for shared diagnostics.
//
//  Small, testable primitives for emails, tokens, UIDs, URLs, and opaque IDs.
//  Higher-level field/JSON policies live in `LogRedactor`.
//
//  Registry: Docs/Architecture/LoggingAndPrivacyContract.md
//

import CryptoKit
import Foundation

enum FormaLogRedactor {

    static let secretPlaceholder = "[REDACTED]"
    static let jsonFieldPlaceholder = "<redacted>"

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

    /// Prefix UID for deletion/export traces (legacy-safe; prefer `hashedUID`).
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

    /// Redacts sensitive substrings in free text. Returns `nil` when input is `nil`.
    static func redact(_ text: String?) -> String? {
        guard let text else { return nil }
        return redactSecrets(in: text)
    }

    /// Redacts bearer tokens, JWTs, API keys, emails, URL query values, Firebase paths,
    /// UUIDs, and long opaque/base64 blobs in free text.
    static func redactSecrets(in text: String) -> String {
        guard !text.isEmpty else { return text }

        var result = redactURLQueryValues(in: text)
        for pattern in secretPatterns {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = pattern.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: secretPlaceholder
            )
        }
        result = emailPattern.stringByReplacingMatches(
            in: result,
            options: [],
            range: NSRange(result.startIndex..<result.endIndex, in: result),
            withTemplate: secretPlaceholder
        )
        return result
    }

    /// Redacts query-parameter values in URLs while preserving parameter names.
    static func redactURLQueryValues(in text: String) -> String {
        guard text.contains("="), text.contains("?") || text.contains("&") else { return text }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return urlQueryValuePattern.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: "$1$2=\(secretPlaceholder)"
        )
    }

    /// Returns `true` when the value contains obvious secret/token/email patterns.
    static func containsObviousSecrets(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        return redactSecrets(in: value) != value
    }

    // MARK: - Private

    private static let secretPatterns: [NSRegularExpression] = {
        let rawPatterns = [
            #"(?i)bearer\s+[A-Za-z0-9\-._~+/]+=*"#,
            #"eyJ[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+"#,
            #"(?i)(api[_-]?key|token|secret|password)\s*[:=]\s*\S+"#,
            #"(?i)users/[A-Za-z0-9_-]{10,40}"#,
            #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#,
            #"(?<![A-Za-z0-9_-])[A-Za-z0-9_-]{28}(?![A-Za-z0-9_-])"#,
            #"[A-Za-z0-9+/]{120,}={0,2}"#
        ]
        return rawPatterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private static let emailPattern: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: [.caseInsensitive])
    }()

    private static let urlQueryValuePattern: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: #"(?i)([?&])([a-zA-Z0-9_.%-]+)=([^&\s#"']*)"#)
    }()
}
