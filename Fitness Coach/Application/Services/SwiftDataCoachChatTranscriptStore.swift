//
//  SwiftDataCoachChatTranscriptStore.swift
//  Fitness Coach
//
//  Forma — SwiftData-backed Coach chat transcript store.
//

import Foundation

@MainActor
final class SwiftDataCoachChatTranscriptStore: CoachChatTranscriptStore {

    private let repository: CoachChatTranscriptPersistenceRepository
    private let userIdProvider: () -> String?

    init(
        repository: CoachChatTranscriptPersistenceRepository,
        userIdProvider: @escaping () -> String? = { nil }
    ) {
        self.repository = repository
        self.userIdProvider = userIdProvider
    }

    convenience init(
        store: SwiftDataStore,
        dateProvider: DateProviding? = nil,
        calendar: Calendar = .current,
        userIdProvider: @escaping () -> String? = { nil }
    ) {
        self.init(
            repository: CoachChatTranscriptPersistenceRepository(
                store: store,
                dateProvider: dateProvider,
                calendar: calendar
            ),
            userIdProvider: userIdProvider
        )
    }

    func loadMessages() -> [ChatMessage] {
        let userId = userIdProvider()
        do {
            if FormaSwiftDataMigrationGate.shouldAllowCoachDataMaintenance() {
                try repository.pruneRetainedOnly(userId: userId)
            }
            return try repository.fetchAllSorted(userId: userId)
        } catch {
            FormaPipelineTracer.logError(
                stage: .error,
                message: "Failed to load Coach chat transcript",
                fields: ["error": error.localizedDescription]
            )
            return []
        }
    }

    func saveMessages(_ messages: [ChatMessage]) {
        do {
            try repository.replaceAll(messages, userId: userIdProvider())
        } catch {
            FormaPipelineTracer.logError(
                stage: .error,
                message: "Failed to save Coach chat transcript",
                fields: ["error": error.localizedDescription]
            )
        }
    }
}
