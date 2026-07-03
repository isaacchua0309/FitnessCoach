//
//  CoachChatTranscriptStore.swift
//  Fitness Coach
//
//  Forma — Persistence boundary for Coach chat transcript messages.
//
//  Coach messages (including `ChatMessageImageAttachment` JPEG bytes) are held in memory
//  for the active session. Cross-launch persistence is not implemented yet.
//

import Foundation

/// Loads and saves Coach chat messages for a session or durable store.
protocol CoachChatTranscriptStore: AnyObject {
    func loadMessages() -> [ChatMessage]
    func saveMessages(_ messages: [ChatMessage])
}

/// Default session store used by `CoachModel` today.
final class CoachInMemoryChatTranscriptStore: CoachChatTranscriptStore {
    private var messages: [ChatMessage] = []

    func loadMessages() -> [ChatMessage] {
        messages
    }

    func saveMessages(_ messages: [ChatMessage]) {
        self.messages = messages
    }
}

// TODO(CoachPersistence): Implement `CoachSwiftDataChatTranscriptStore` backed by a new
// SwiftData entity that persists text fields plus image JPEG/thumbnail blobs (or file URLs
// under Application Support). `ChatMessageEntity` is legacy v1-only and cannot store images.
// Wire through `CoachModel` init once entity + migration are ready.
