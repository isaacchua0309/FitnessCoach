//
//  CoachTimelineRecorderTests.swift
//  Fitness CoachTests
//
//  Forma — CoachTimelineRecording best-effort recorder tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachTimelineRecorderTests: XCTestCase {

    private var store: FakeCoachTimelineStore!
    private var recorder: DefaultCoachTimelineRecorder!
    private var calendar: Calendar!
    private var now: Date!

    override func setUp() async throws {
        calendar = CoachTimelineRecorderTestFixtures.calendar
        now = CoachTimelineRecorderTestFixtures.referenceNow
        store = FakeCoachTimelineStore()
        recorder = DefaultCoachTimelineRecorder(store: store, calendar: calendar)
    }

    override func tearDown() {
        store = nil
        recorder = nil
        calendar = nil
        now = nil
        super.tearDown()
    }

    // MARK: Conversation

    func testRecordUserMessageBuildsEventWithLinksAndTimestamps() async throws {
        let messageId = UUID()

        recorder.recordUserMessage(
            text: "  Log my lunch  ",
            messageId: messageId,
            hasPhotoAttachment: true,
            occurredAt: now
        )

        let event = try await store.waitForLatestEvent()
        XCTAssertEqual(event.type, .userMessage)
        XCTAssertEqual(event.source, .coachUI)
        XCTAssertEqual(event.sourceAttribution, .localParser)
        XCTAssertEqual(event.status, .confirmed)
        XCTAssertEqual(event.linkedMessageId, messageId)
        XCTAssertEqual(event.localDate, "2026-07-03")
        XCTAssertEqual(event.timezoneIdentifier, calendar.timeZone.identifier)

        guard case .message(let payload) = event.payload else {
            return XCTFail("Expected message payload")
        }
        XCTAssertEqual(payload.textPreview, "Log my lunch")
        XCTAssertEqual(payload.fullText, "Log my lunch")
        XCTAssertEqual(payload.role, "user")
        XCTAssertTrue(payload.hasPhotoAttachment)
        XCTAssertEqual(
            CoachTimelineEventSummaryBuilder.summary(for: event),
            "Log my lunch"
        )
    }

    func testRecordAssistantMessageUsesSourceAttribution() async throws {
        let messageId = UUID()

        recorder.recordAssistantMessage(
            text: "Here is your estimate.",
            messageId: messageId,
            sourceAttribution: .estimateFood,
            occurredAt: now
        )

        let event = try await store.waitForLatestEvent()
        XCTAssertEqual(event.type, .assistantMessage)
        XCTAssertEqual(event.source, .aiBackend)
        XCTAssertEqual(event.sourceAttribution, .estimateFood)
        XCTAssertEqual(event.linkedMessageId, messageId)
    }

    // MARK: Food lifecycle

    func testRecordFoodEstimateCreated() async throws {
        let estimateId = UUID()
        let messageId = UUID()
        let sessionId = UUID()

        recorder.recordFoodEstimateCreated(
            payload: FoodEstimatePayload(
                estimateId: estimateId,
                mealName: "Chicken bowl",
                calories: 620,
                requiresConfirmation: true
            ),
            source: .aiBackend,
            sourceAttribution: .estimateFood,
            confidence: .medium,
            status: .pending,
            messageId: messageId,
            photoSessionId: sessionId,
            relatedEventIds: [],
            occurredAt: now
        )

        let event = try await store.waitForLatestEvent()
        XCTAssertEqual(event.type, .foodEstimateCreated)
        XCTAssertEqual(event.confidence, .medium)
        XCTAssertEqual(event.status, .pending)
        XCTAssertEqual(event.linkedMessageId, messageId)
        XCTAssertEqual(event.link.linkedPhotoSessionId, sessionId)
        XCTAssertEqual(
            CoachTimelineEventSummaryBuilder.summary(for: event),
            "Estimate: Chicken bowl"
        )
    }

    func testRecordFoodLoggedMapsEntry() async throws {
        let entry = CoachTimelineRecorderTestFixtures.foodEntry(occurredAt: now)

        recorder.recordFoodLogged(
            entry: entry,
            sourceAttribution: .userConfirmation,
            userEditedBeforeConfirm: false,
            linkedPhotoSessionId: nil,
            occurredAt: now
        )

        let event = try await store.waitForLatestEvent()
        XCTAssertEqual(event.type, .foodLogged)
        XCTAssertEqual(event.linkedEntryId, entry.id)
        XCTAssertEqual(event.link.linkedDailyLogId, entry.dailyLogId)

        guard case .foodLogged(let payload) = event.payload else {
            return XCTFail("Expected foodLogged payload")
        }
        XCTAssertEqual(payload.name, entry.name)
        XCTAssertEqual(payload.calories, entry.calories)
        XCTAssertFalse(payload.isEdit)
        XCTAssertFalse(payload.isDelete)
    }

    func testRecordFoodEditedAndDeletedFlags() async throws {
        let entry = CoachTimelineRecorderTestFixtures.foodEntry(occurredAt: now)

        recorder.recordFoodEdited(entry: entry, occurredAt: now)
        let edited = try await store.waitForEventCount(1)
        guard case .foodLogged(let editPayload) = edited.payload else {
            return XCTFail("Expected foodLogged payload")
        }
        XCTAssertTrue(editPayload.isEdit)

        recorder.recordFoodDeleted(entry: entry, occurredAt: now)
        let deleted = try await store.waitForEventCount(2)
        guard case .foodLogged(let deletePayload) = deleted.payload else {
            return XCTFail("Expected foodLogged payload")
        }
        XCTAssertTrue(deletePayload.isDelete)
    }

    func testRecordFoodRejectedUsesRejectedStatus() async throws {
        recorder.recordFoodRejected(
            payload: FoodEstimatePayload(mealName: "Pizza", requiresConfirmation: true),
            messageId: nil,
            photoSessionId: nil,
            relatedEventIds: [],
            occurredAt: now
        )

        let event = try await store.waitForLatestEvent()
        XCTAssertEqual(event.type, .foodRejected)
        XCTAssertEqual(event.status, .rejected)
    }

    // MARK: Hydration, weight, health

    func testRecordWaterAndWeightLogged() async throws {
        let water = WaterEntry(
            id: UUID(),
            dailyLogId: UUID(),
            amountMl: 500,
            createdAt: now
        )
        recorder.recordWaterLogged(entry: water, occurredAt: now)
        let waterEvent = try await store.waitForEventCount(1)
        XCTAssertEqual(waterEvent.type, .waterLogged)
        XCTAssertEqual(waterEvent.linkedEntryId, water.id)

        let weight = WeightEntry(
            id: UUID(),
            date: now,
            weightKg: 72.5,
            note: nil,
            createdAt: now
        )
        recorder.recordWeightLogged(entry: weight, occurredAt: now)
        let weightEvent = try await store.waitForEventCount(2)
        XCTAssertEqual(weightEvent.type, .weightLogged)
        XCTAssertEqual(weightEvent.linkedEntryId, weight.id)
    }

    func testRecordWorkoutDetectedAndStepsUpdated() async throws {
        recorder.recordWorkoutDetected(
            workoutCount: 2,
            totalDurationMinutes: 45,
            totalActiveCalories: 320,
            primaryWorkoutTitle: "Run",
            demand: "moderate",
            occurredAt: now
        )
        let workoutEvent = try await store.waitForEventCount(1)
        XCTAssertEqual(workoutEvent.type, .workoutDetected)
        XCTAssertEqual(workoutEvent.sourceAttribution, .healthKit)

        recorder.recordStepsUpdated(steps: 8_500, previousSteps: 7_200, occurredAt: now)
        let stepsEvent = try await store.waitForEventCount(2)
        XCTAssertEqual(stepsEvent.type, .stepsUpdated)
    }

    // MARK: Photo analysis

    func testRecordPhotoLifecycle() async throws {
        let sessionId = UUID()
        let messageId = UUID()

        recorder.recordPhotoAttached(
            payload: PhotoPayload(
                sessionId: sessionId,
                mimeType: "image/jpeg",
                compressedByteSize: 120_000,
                attachmentSource: "camera",
                hasCaption: true
            ),
            messageId: messageId,
            occurredAt: now
        )
        let attached = try await store.waitForEventCount(1)
        XCTAssertEqual(attached.type, .photoAttached)
        XCTAssertEqual(attached.link.linkedPhotoSessionId, sessionId)

        recorder.recordPhotoAnalysisStarted(sessionId: sessionId, messageId: messageId, occurredAt: now)
        let started = try await store.waitForEventCount(2)
        XCTAssertEqual(started.type, .photoAnalysisStarted)
        XCTAssertEqual(started.status, .pending)

        recorder.recordPhotoAnalysisCompleted(
            sessionId: sessionId,
            messageId: messageId,
            mealName: "Salad",
            estimateId: UUID(),
            confidence: .high,
            occurredAt: now
        )
        let completed = try await store.waitForEventCount(3)
        XCTAssertEqual(completed.type, .photoAnalysisCompleted)
        XCTAssertEqual(completed.confidence, .high)

        recorder.recordPhotoAnalysisFailed(
            sessionId: sessionId,
            messageId: messageId,
            errorCategory: "rate_limited",
            userMessage: "Try again soon",
            isRetryable: true,
            occurredAt: now
        )
        let failed = try await store.waitForEventCount(4)
        XCTAssertEqual(failed.type, .photoAnalysisFailed)
        XCTAssertEqual(failed.status, .failed)
    }

    // MARK: Clarification & confirmation

    func testRecordClarificationLoop() async throws {
        let sessionId = UUID()

        recorder.recordClarificationAsked(
            question: "How large was the portion?",
            messageId: UUID(),
            sessionId: sessionId,
            occurredAt: now
        )
        let asked = try await store.waitForEventCount(1)
        XCTAssertEqual(asked.type, .clarificationAsked)
        XCTAssertEqual(asked.link.linkedPhotoSessionId, sessionId)

        recorder.recordClarificationAnswered(
            answer: "About one cup",
            messageId: UUID(),
            sessionId: sessionId,
            occurredAt: now
        )
        let answered = try await store.waitForEventCount(2)
        XCTAssertEqual(answered.type, .clarificationAnswered)
    }

    func testRecordPendingConfirmationLifecycle() async throws {
        let confirmationId = UUID()
        let payload = ConfirmationPayload(
            kind: "food",
            originalText: "log chicken",
            assistantMessagePreview: "Log chicken bowl?",
            pendingConfirmationId: confirmationId
        )

        recorder.recordPendingConfirmationCreated(payload: payload, occurredAt: now)
        let created = try await store.waitForEventCount(1)
        XCTAssertEqual(created.type, .pendingConfirmationCreated)
        XCTAssertEqual(created.status, .pending)

        recorder.recordPendingConfirmationConfirmed(payload: payload, entryId: UUID(), occurredAt: now)
        let confirmed = try await store.waitForEventCount(2)
        XCTAssertEqual(confirmed.type, .pendingConfirmationConfirmed)

        recorder.recordPendingConfirmationRejected(payload: payload, occurredAt: now)
        let rejected = try await store.waitForEventCount(3)
        XCTAssertEqual(rejected.type, .pendingConfirmationRejected)
        XCTAssertEqual(rejected.status, .rejected)
    }

    // MARK: Undo & errors

    func testRecordUndoPerformed() async throws {
        let entryId = UUID()
        recorder.recordUndoPerformed(
            entryType: "food",
            undoneEntryId: entryId,
            summary: "Removed last meal",
            occurredAt: now
        )

        let event = try await store.waitForLatestEvent()
        XCTAssertEqual(event.type, .undoPerformed)
        XCTAssertEqual(event.linkedEntryId, entryId)
    }

    func testRecordBackendAndAuthErrors() async throws {
        recorder.recordBackendError(
            category: "rate_limited",
            userMessage: "Slow down",
            isRetryable: true,
            httpStatus: 429,
            occurredAt: now
        )
        let backend = try await store.waitForEventCount(1)
        XCTAssertEqual(backend.type, .backendError)
        XCTAssertEqual(backend.sourceAttribution, .system)

        recorder.recordAuthError(userMessage: "Session expired", occurredAt: now)
        let auth = try await store.waitForEventCount(2)
        XCTAssertEqual(auth.type, .authError)
        guard case .error(let payload) = auth.payload else {
            return XCTFail("Expected error payload")
        }
        XCTAssertEqual(payload.category, "authentication")
        XCTAssertTrue(payload.isRetryable)
    }

    func testRecordHealthDataUnavailableAndContextGenerated() async throws {
        recorder.recordHealthDataUnavailable(
            missingSignals: ["recovery", "steps"],
            reason: "HealthKit not authorized",
            healthIntelligenceAwarenessAvailable: false,
            occurredAt: now
        )
        let health = try await store.waitForEventCount(1)
        XCTAssertEqual(health.type, .healthDataUnavailable)
        XCTAssertEqual(health.sourceAttribution, .healthIntelligence)

        recorder.recordContextGenerated(
            payload: ContextGenerationPayload(
                lookbackDays: 7,
                timelineEventCount: 12,
                recentMessageCount: 5,
                hasTodaySummary: true,
                hasHealthIntelligence: true,
                healthIntelligenceAwarenessAvailable: true,
                contextByteEstimate: 4_096,
                trigger: "coach_send"
            ),
            occurredAt: now
        )
        let context = try await store.waitForEventCount(2)
        XCTAssertEqual(context.type, .contextGenerated)
        XCTAssertEqual(
            CoachTimelineEventSummaryBuilder.summary(for: context),
            "Context generated (7d lookback)"
        )
    }

    // MARK: Safety

    func testNilStoreIsNoOpAndDoesNotCrash() async {
        let nilRecorder = DefaultCoachTimelineRecorder(store: nil, calendar: calendar)
        nilRecorder.recordUserMessage(
            text: "Hello",
            messageId: nil,
            hasPhotoAttachment: false,
            occurredAt: now
        )
        await Task.yield()
        XCTAssertTrue(store.events.isEmpty)
    }

    func testAppendFailureDoesNotCrashRecorder() async throws {
        store.injectedAppendError = CoachTimelineStoreError.invalidDateRange

        recorder.recordUserMessage(
            text: "Hello",
            messageId: nil,
            hasPhotoAttachment: false,
            occurredAt: now
        )

        try await waitUntil(timeout: 0.5) {
            self.store.appendAttempts == 1
        }
        XCTAssertTrue(store.events.isEmpty)
    }

    func testFoodLogDraftTimelineEstimatePayloadHelper() {
        let draft = FoodLogDraft(
            displayName: "Oatmeal",
            mealType: .breakfast,
            components: [
                FoodComponent(
                    name: "Oats",
                    quantity: 1,
                    unit: "cup",
                    calories: 300,
                    protein: 10,
                    carbs: 50,
                    fat: 5
                )
            ],
            confidence: .high
        )

        let payload = draft.timelineEstimatePayload(originalText: "oatmeal")
        XCTAssertEqual(payload.mealName, "Oatmeal")
        XCTAssertEqual(payload.mealType, MealType.breakfast.rawValue)
        XCTAssertEqual(payload.calories, 300)
        XCTAssertEqual(payload.componentCount, 1)
        XCTAssertEqual(CoachTimelineEventConfidence.from(.high), .high)
    }
}

// MARK: - Fake store

@MainActor
final class FakeCoachTimelineStore: CoachTimelineStoring {

    private(set) var events: [CoachTimelineEvent] = []
    private(set) var appendAttempts = 0
    var injectedAppendError: Error?

    func append(_ event: CoachTimelineEvent) async throws {
        appendAttempts += 1
        if let injectedAppendError {
            throw injectedAppendError
        }
        guard !events.contains(where: { $0.id == event.id }) else { return }
        events.append(event)
    }

    func appendMany(_ events: [CoachTimelineEvent]) async throws {
        for event in events {
            try await append(event)
        }
    }

    func events(forLocalDate localDate: String) async throws -> [CoachTimelineEvent] {
        events.filter { $0.localDate == localDate }
    }

    func events(from start: Date, to end: Date) async throws -> [CoachTimelineEvent] {
        guard start <= end else {
            throw CoachTimelineStoreError.invalidDateRange
        }
        return events.filter { $0.utcTimestamp >= start && $0.utcTimestamp <= end }
    }

    func recentEvents(limit: Int, before date: Date?) async throws -> [CoachTimelineEvent] {
        let filtered = events.filter { event in
            guard let date else { return true }
            return event.utcTimestamp < date
        }
        return Array(
            filtered
                .sorted { $0.utcTimestamp > $1.utcTimestamp }
                .prefix(limit)
                .sorted { $0.utcTimestamp < $1.utcTimestamp }
        )
    }

    func event(id: UUID) async throws -> CoachTimelineEvent? {
        events.first { $0.id == id }
    }

    func markEventStatus(id: UUID, status: CoachTimelineEventStatus) async throws {
        guard let index = events.firstIndex(where: { $0.id == id }) else {
            throw CoachTimelineStoreError.eventNotFound(id)
        }
        events[index].status = status
    }

    func supersedeEvent(id: UUID, by newEvent: CoachTimelineEvent) async throws {
        try await markEventStatus(id: id, status: .superseded)
        var replacement = newEvent
        if replacement.supersedesEventId != id {
            replacement = CoachTimelineEvent(
                id: replacement.id,
                type: replacement.type,
                source: replacement.source,
                sourceAttribution: replacement.sourceAttribution,
                confidence: replacement.confidence,
                status: replacement.status,
                payload: replacement.payload,
                utcTimestamp: replacement.utcTimestamp,
                localTimestamp: replacement.localTimestamp,
                timezoneIdentifier: replacement.timezoneIdentifier,
                localDate: replacement.localDate,
                link: replacement.link,
                supersedesEventId: id,
                recordedAt: replacement.recordedAt
            )
        }
        try await append(replacement)
    }

    func deleteEventsOlderThan(policy: CoachTimelineCompactionPolicy) async throws {
        _ = policy
    }

    func waitForLatestEvent(timeout: TimeInterval = 1.0) async throws -> CoachTimelineEvent {
        try await waitForEventCount(1, timeout: timeout)
        return events.last!
    }

    func waitForEventCount(_ count: Int, timeout: TimeInterval = 1.0) async throws -> CoachTimelineEvent {
        try await waitUntil(timeout: timeout) {
            self.events.count >= count
        }
        return events[count - 1]
    }
}

// MARK: - Fixtures

private enum CoachTimelineRecorderTestFixtures {

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    static let referenceNow: Date = {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 7
        components.day = 3
        components.hour = 12
        return calendar.date(from: components)!
    }()

    static func foodEntry(occurredAt: Date) -> FoodEntry {
        FoodEntry(
            id: UUID(),
            dailyLogId: UUID(),
            mealType: .lunch,
            name: "Salad",
            quantity: 1,
            unit: "bowl",
            calories: 420,
            protein: 25,
            carbs: 30,
            fat: 12,
            source: .aiTextEstimate,
            confidence: .medium,
            createdAt: occurredAt,
            updatedAt: occurredAt
        )
    }
}

// MARK: - Async wait helpers

private func waitUntil(
    timeout: TimeInterval = 1.0,
    pollIntervalNanoseconds: UInt64 = 10_000_000,
    _ predicate: @escaping () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !predicate() {
        if Date() > deadline {
            throw NSError(
                domain: "CoachTimelineRecorderTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for condition"]
            )
        }
        await Task.yield()
        try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
    }
}
