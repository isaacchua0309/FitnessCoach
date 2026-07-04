//
//  CoachChatTranscriptStore.swift
//  Fitness Coach
//
//  Forma — Persistence boundary for Coach chat transcript messages.
//

import Foundation

/// Loads and saves Coach chat messages for a session or durable store.
protocol CoachChatTranscriptStore: AnyObject {
    func loadMessages() -> [ChatMessage]
    func saveMessages(_ messages: [ChatMessage])
}

/// In-memory store for tests, previews, and isolated Coach flows.
final class CoachInMemoryChatTranscriptStore: CoachChatTranscriptStore {
    private var messages: [ChatMessage] = []

    func loadMessages() -> [ChatMessage] {
        messages
    }

    func saveMessages(_ messages: [ChatMessage]) {
        self.messages = messages
    }
}
