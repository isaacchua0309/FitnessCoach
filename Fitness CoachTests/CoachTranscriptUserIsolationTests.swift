//
//  CoachTranscriptUserIsolationTests.swift
//  Fitness CoachTests
//
//  Forma — Phase 1 coach transcript UID isolation.
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class CoachTranscriptUserIsolationTests: XCTestCase {

    private var sessionUID = CoachTranscriptTestSessionUID()

    override func tearDown() {
        sessionUID.uid = nil
        super.tearDown()
    }

    func testUserBDoesNotSeeUserACoachTranscript() throws {
        let harness = try makeHarness()

        let userAMessage = ChatMessage(
            id: UUID(),
            role: .user,
            text: "User A message",
            createdAt: ProfileTestFixtures.referenceDate
        )
        try harness.repository.replaceAll([userAMessage], userId: "user-a")

        let messagesForB = try harness.repository.fetchAllSorted(userId: "user-b")
        XCTAssertTrue(messagesForB.isEmpty)
    }

    func testNilUserIdCoachRowsExcludedForSignedInUser() throws {
        let harness = try makeHarness()

        let legacyMessage = ChatMessage(
            id: UUID(),
            role: .assistant,
            text: "Legacy coach reply",
            createdAt: ProfileTestFixtures.referenceDate
        )
        let entity = CoachChatTranscriptMessageEntity(
            model: legacyMessage,
            userId: nil,
            updatedAt: ProfileTestFixtures.referenceDate
        )
        harness.store.modelContext.insert(entity)
        try harness.store.save()

        let signedInMessages = try harness.repository.fetchAllSorted(userId: "signed-in-user")
        XCTAssertTrue(signedInMessages.isEmpty)
    }

    func testCoachRetentionPrunesOnlyCurrentUser() throws {
        let harness = try makeHarness()
        var userAMessages: [ChatMessage] = []
        for index in 0..<305 {
            userAMessages.append(
                ChatMessage(
                    role: index.isMultiple(of: 2) ? .user : .assistant,
                    text: "user-a \(index)",
                    createdAt: ProfileTestFixtures.referenceDate.addingTimeInterval(TimeInterval(index))
                )
            )
        }
        try harness.repository.replaceAll(userAMessages, userId: "user-a")

        let userBMessage = ChatMessage(
            role: .user,
            text: "user-b only",
            createdAt: ProfileTestFixtures.referenceDate.addingTimeInterval(10_000)
        )
        try harness.repository.replaceAll([userBMessage], userId: "user-b")

        try harness.repository.pruneRetainedOnly(userId: "user-a")

        XCTAssertEqual(try harness.repository.fetchAllSorted(userId: "user-a").count, 300)
        XCTAssertEqual(try harness.repository.fetchAllSorted(userId: "user-b").count, 1)
        XCTAssertEqual(try harness.repository.fetchAllSorted(userId: "user-b").first?.text, "user-b only")
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
        sessionUID.uid = "signed-in-user"
        let store = SwiftDataCoachChatTranscriptStore(
            repository: harness.repository,
            userIdProvider: { [sessionUID] in sessionUID.uid }
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
        let store: SwiftDataStore
        let repository: CoachChatTranscriptPersistenceRepository
    }

    private func makeHarness() throws -> Harness {
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let repository = CoachChatTranscriptPersistenceRepository(store: store)
        return Harness(store: store, repository: repository)
    }
}

@MainActor
private final class CoachTranscriptTestSessionUID {
    var uid: String?
}
