//
//  CoachTranscriptUserIsolationTests.swift
//  Fitness CoachTests
//
//  Forma — Phase 1 coach transcript UID isolation.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachTranscriptUserIsolationTests: XCTestCase {

    func testNilUserIdCoachRowsExcludedForSignedInUser() throws {
        let harness = try makeHarness()

        let legacyMessage = ChatMessage(
            id: UUID(),
            role: .assistant,
            text: "Legacy coach reply",
            createdAt: ProfileTestFixtures.referenceDate
        )
        try harness.repository.replaceAll([legacyMessage], userId: nil)

        let signedInMessages = try harness.repository.fetchAllSorted(userId: "signed-in-user")
        XCTAssertTrue(signedInMessages.isEmpty)
    }

    func testCoachTranscriptIsolatedByUserId() throws {
        let harness = try makeHarness()

        let userAMessage = ChatMessage(
            id: UUID(),
            role: .user,
            text: "User A message",
            createdAt: ProfileTestFixtures.referenceDate
        )
        let userBMessage = ChatMessage(
            id: UUID(),
            role: .user,
            text: "User B message",
            createdAt: ProfileTestFixtures.referenceDate.addingTimeInterval(60)
        )

        try harness.repository.replaceAll([userAMessage], userId: "user-a")
        try harness.repository.replaceAll([userBMessage], userId: "user-b")

        let messagesForA = try harness.repository.fetchAllSorted(userId: "user-a")
        XCTAssertEqual(messagesForA.count, 1)
        XCTAssertEqual(messagesForA.first?.text, "User A message")

        let messagesForB = try harness.repository.fetchAllSorted(userId: "user-b")
        XCTAssertEqual(messagesForB.count, 1)
        XCTAssertEqual(messagesForB.first?.text, "User B message")
    }

    func testSignedInSaveRequiresExplicitUserId() throws {
        let harness = try makeHarness()
        let store = SwiftDataCoachChatTranscriptStore(
            repository: harness.repository,
            userIdProvider: { "signed-in-user" }
        )

        let message = ChatMessage(
            id: UUID(),
            role: .user,
            text: "Persisted for signed-in user",
            createdAt: ProfileTestFixtures.referenceDate
        )
        store.saveMessages([message])

        let entities = try harness.repository.persistedEntities(userId: "signed-in-user")
        XCTAssertEqual(entities.count, 1)
        XCTAssertEqual(entities.first?.userId, "signed-in-user")
    }

    // MARK: - Harness

    private struct Harness {
        let repository: CoachChatTranscriptPersistenceRepository
    }

    private func makeHarness() throws -> Harness {
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let repository = CoachChatTranscriptPersistenceRepository(store: store)
        return Harness(repository: repository)
    }
}
