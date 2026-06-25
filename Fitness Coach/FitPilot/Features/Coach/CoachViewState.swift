//
//  CoachViewState.swift
//  Fitness Coach
//
//  FitPilot AI — Lightweight view state for the Coach chat shell.
//
//  This is app-facing display state only. It holds in-memory chat messages and
//  input state; it is not the source of truth for any logs.
//

import Foundation

struct CoachViewState: Equatable {
    var messages: [ChatMessage]
    var inputText: String
    var isSending: Bool
    var errorMessage: String?

    init(
        messages: [ChatMessage] = [],
        inputText: String = "",
        isSending: Bool = false,
        errorMessage: String? = nil
    ) {
        self.messages = messages
        self.inputText = inputText
        self.isSending = isSending
        self.errorMessage = errorMessage
    }

    var hasMessages: Bool {
        !messages.isEmpty
    }

    var canSend: Bool {
        !isSending && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
