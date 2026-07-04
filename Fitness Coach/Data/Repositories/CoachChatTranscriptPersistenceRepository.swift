//
//  CoachChatTranscriptPersistenceRepository.swift
//  Fitness Coach
//
//  Forma — Low-level SwiftData access for Coach chat transcript messages.
//

import Foundation
import SwiftData

@MainActor
final class CoachChatTranscriptPersistenceRepository {

    private let store: SwiftDataStore
    private let dateProvider: DateProviding
    private let calendar: Calendar

    init(
        store: SwiftDataStore,
        dateProvider: DateProviding? = nil,
        calendar: Calendar = .current
    ) {
        self.store = store
        self.dateProvider = dateProvider ?? SystemDateProvider()
        self.calendar = calendar
    }

    func fetchAllSorted(userId: String?) throws -> [ChatMessage] {
        try fetchEntities(userId: userId)
            .map { $0.toModel() }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func replaceAll(_ messages: [ChatMessage], userId: String?) throws {
        let userId = try UserDataOwnerScope.requiredSessionUID(
            userId,
            operation: "save coach transcript"
        )
        let retained = CoachChatTranscriptRetentionPolicy.retainedMessages(
            from: messages,
            now: dateProvider.now,
            calendar: calendar
        )
        let retainedIDs = Set(retained.map(\.id))
        let existing = try fetchEntities(userId: userId)
        let now = dateProvider.now

        for message in retained {
            if let entity = try entity(id: message.id, userId: userId) {
                entity.update(from: message, updatedAt: now)
            } else {
                let entity = CoachChatTranscriptMessageEntity(model: message, userId: userId, updatedAt: now)
                UserDataOwnerScope.stampNewCoachWrite(on: entity, userId: userId, now: now)
                store.modelContext.insert(entity)
            }
        }

        for entity in existing where !retainedIDs.contains(entity.id) {
            store.modelContext.delete(entity)
        }

        try store.save()
    }

    func pruneRetainedOnly(userId: String?) throws {
        guard let userId else { return }
        let all = try fetchAllSorted(userId: userId)
        let retained = CoachChatTranscriptRetentionPolicy.retainedMessages(
            from: all,
            now: dateProvider.now,
            calendar: calendar
        )
        guard retained.count < all.count else { return }
        try replaceAll(retained, userId: userId)
    }

    func persistedEntities(userId: String?) throws -> [CoachChatTranscriptMessageEntity] {
        try fetchEntities(userId: userId)
    }

    // MARK: - Private

    private func fetchEntities(userId: String?) throws -> [CoachChatTranscriptMessageEntity] {
        let entities = try store.fetch(FetchDescriptor<CoachChatTranscriptMessageEntity>())
        return UserDataOwnerScope.filterVisibleCoachEntities(entities, sessionUID: userId)
    }

    private func entity(id: UUID, userId: String?) throws -> CoachChatTranscriptMessageEntity? {
        var descriptor = FetchDescriptor<CoachChatTranscriptMessageEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let entity = try store.fetch(descriptor).first else { return nil }
        guard UserDataOwnerScope.isCoachRowVisible(entityUserId: entity.userId, sessionUID: userId) else {
            return nil
        }
        return entity
    }
}
