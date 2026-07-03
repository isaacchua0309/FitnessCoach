//
//  CoachChatTranscriptRetentionPolicy.swift
//  Fitness Coach
//
//  Forma — Retention rules for persisted Coach chat transcripts.
//

import Foundation

enum CoachChatTranscriptRetentionPolicy {

    /// Keep messages from the last 30 calendar days.
    static let maxAgeDays = 30

    /// Hard cap on persisted transcript length.
    static let maxMessageCount = 300

    /// Full-resolution JPEG bytes are only persisted when at or below this size.
    static let maxPersistedFullImageBytes = 64 * 1024

    /// Applies both age and count limits — whichever constraint removes more data wins.
    static func retainedMessages(
        from messages: [ChatMessage],
        now: Date,
        calendar: Calendar = .current
    ) -> [ChatMessage] {
        let sorted = messages.sorted { $0.createdAt < $1.createdAt }
        guard !sorted.isEmpty else { return [] }

        let cutoff = calendar.date(byAdding: .day, value: -maxAgeDays, to: now) ?? .distantPast
        let withinAge = sorted.filter { $0.createdAt >= cutoff }
        guard withinAge.count > maxMessageCount else { return withinAge }
        return Array(withinAge.suffix(maxMessageCount))
    }
}
