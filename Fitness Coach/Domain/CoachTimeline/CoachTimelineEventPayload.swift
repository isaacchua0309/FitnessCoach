//
//  CoachTimelineEventPayload.swift
//  Fitness Coach
//
//  Forma — Structured payloads for Coach timeline events.
//
//  Payloads are persistence-safe: no image bytes, HealthKit types, UI types,
//  or secrets. Use metadata and stable IDs only.
//

import Foundation

// MARK: - Payload structs

/// Text content for user, assistant, or clarification messages.
struct MessagePayload: Codable, Equatable, Sendable {
    /// Truncated preview safe for logs and AI context (full text may live on `ChatMessage`).
    var textPreview: String
    /// Optional full text when already bounded by Coach input limits.
    var fullText: String?
    /// Conversation role when the event originated from chat.
    var role: String?
    /// Whether the message included a staged meal-photo attachment.
    var hasPhotoAttachment: Bool

    init(
        textPreview: String,
        fullText: String? = nil,
        role: String? = nil,
        hasPhotoAttachment: Bool = false
    ) {
        self.textPreview = textPreview
        self.fullText = fullText
        self.role = role
        self.hasPhotoAttachment = hasPhotoAttachment
    }
}

/// Food estimate produced by local parser, classifier, or AI — not yet logged.
struct FoodEstimatePayload: Codable, Equatable, Sendable {
    var estimateId: UUID?
    var mealName: String
    var mealType: String?
    var calories: Int?
    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?
    var componentCount: Int?
    var requiresConfirmation: Bool
    var originalText: String?
    var sanityWarning: String?

    init(
        estimateId: UUID? = nil,
        mealName: String,
        mealType: String? = nil,
        calories: Int? = nil,
        proteinGrams: Double? = nil,
        carbsGrams: Double? = nil,
        fatGrams: Double? = nil,
        componentCount: Int? = nil,
        requiresConfirmation: Bool = true,
        originalText: String? = nil,
        sanityWarning: String? = nil
    ) {
        self.estimateId = estimateId
        self.mealName = mealName
        self.mealType = mealType
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.componentCount = componentCount
        self.requiresConfirmation = requiresConfirmation
        self.originalText = originalText
        self.sanityWarning = sanityWarning
    }
}

/// Committed or edited food log entry snapshot.
struct FoodLoggedPayload: Codable, Equatable, Sendable {
    var entryId: UUID
    var dailyLogId: UUID?
    var mealType: String?
    var name: String
    var quantity: Double?
    var unit: String?
    var calories: Int
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var source: String?
    var confidence: String?
    var userEditedBeforeConfirm: Bool?
    var isEdit: Bool
    var isDelete: Bool

    init(
        entryId: UUID,
        dailyLogId: UUID? = nil,
        mealType: String? = nil,
        name: String,
        quantity: Double? = nil,
        unit: String? = nil,
        calories: Int,
        proteinGrams: Double,
        carbsGrams: Double,
        fatGrams: Double,
        source: String? = nil,
        confidence: String? = nil,
        userEditedBeforeConfirm: Bool? = nil,
        isEdit: Bool = false,
        isDelete: Bool = false
    ) {
        self.entryId = entryId
        self.dailyLogId = dailyLogId
        self.mealType = mealType
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.source = source
        self.confidence = confidence
        self.userEditedBeforeConfirm = userEditedBeforeConfirm
        self.isEdit = isEdit
        self.isDelete = isDelete
    }
}

/// Committed water log entry snapshot.
struct WaterLoggedPayload: Codable, Equatable, Sendable {
    var entryId: UUID
    var dailyLogId: UUID?
    var amountMl: Int

    init(entryId: UUID, dailyLogId: UUID? = nil, amountMl: Int) {
        self.entryId = entryId
        self.dailyLogId = dailyLogId
        self.amountMl = amountMl
    }
}

/// Committed weight log entry snapshot.
struct WeightLoggedPayload: Codable, Equatable, Sendable {
    var entryId: UUID
    var weightKg: Double
    var note: String?

    init(entryId: UUID, weightKg: Double, note: String? = nil) {
        self.entryId = entryId
        self.weightKg = weightKg
        self.note = note
    }
}

/// Apple Health workout activity observed for a calendar day (read-only).
struct WorkoutDetectedPayload: Codable, Equatable, Sendable {
    var workoutCount: Int
    var totalDurationMinutes: Int
    var totalActiveCalories: Int?
    var primaryWorkoutTitle: String?
    var demand: String?

    init(
        workoutCount: Int,
        totalDurationMinutes: Int = 0,
        totalActiveCalories: Int? = nil,
        primaryWorkoutTitle: String? = nil,
        demand: String? = nil
    ) {
        self.workoutCount = workoutCount
        self.totalDurationMinutes = totalDurationMinutes
        self.totalActiveCalories = totalActiveCalories
        self.primaryWorkoutTitle = primaryWorkoutTitle
        self.demand = demand
    }
}

/// Step count update for a calendar day.
struct StepsPayload: Codable, Equatable, Sendable {
    var steps: Int
    var previousSteps: Int?

    init(steps: Int, previousSteps: Int? = nil) {
        self.steps = steps
        self.previousSteps = previousSteps
    }
}

/// Meal photo metadata — never includes raw JPEG bytes.
struct PhotoPayload: Codable, Equatable, Sendable {
    var sessionId: UUID?
    var mimeType: String?
    var compressedByteSize: Int?
    var pixelWidth: Int?
    var pixelHeight: Int?
    /// Attachment source label, e.g. `camera` or `library`.
    var attachmentSource: String?
    var hasCaption: Bool
    var attemptNumber: Int?
    var isRetry: Bool
    var isRecommission: Bool

    init(
        sessionId: UUID? = nil,
        mimeType: String? = nil,
        compressedByteSize: Int? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        attachmentSource: String? = nil,
        hasCaption: Bool = false,
        attemptNumber: Int? = nil,
        isRetry: Bool = false,
        isRecommission: Bool = false
    ) {
        self.sessionId = sessionId
        self.mimeType = mimeType
        self.compressedByteSize = compressedByteSize
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.attachmentSource = attachmentSource
        self.hasCaption = hasCaption
        self.attemptNumber = attemptNumber
        self.isRetry = isRetry
        self.isRecommission = isRecommission
    }
}

/// Pending confirmation bar or typed confirm/reject flow.
struct ConfirmationPayload: Codable, Equatable, Sendable {
    /// Domain label: `food`, `water`, `weight`, `edit`, `delete`, `undo`.
    var kind: String
    var originalText: String?
    var assistantMessagePreview: String?
    var pendingConfirmationId: UUID?
    var relatedPhotoSessionId: UUID?
    var userInputMethod: String?

    init(
        kind: String,
        originalText: String? = nil,
        assistantMessagePreview: String? = nil,
        pendingConfirmationId: UUID? = nil,
        relatedPhotoSessionId: UUID? = nil,
        userInputMethod: String? = nil
    ) {
        self.kind = kind
        self.originalText = originalText
        self.assistantMessagePreview = assistantMessagePreview
        self.pendingConfirmationId = pendingConfirmationId
        self.relatedPhotoSessionId = relatedPhotoSessionId
        self.userInputMethod = userInputMethod
    }
}

/// Recoverable or surfaced error (backend, auth, validation).
struct ErrorPayload: Codable, Equatable, Sendable {
    /// Stable category for analytics, e.g. `authentication`, `rate_limited`.
    var category: String
    var userMessagePreview: String?
    var isRetryable: Bool
    var httpStatus: Int?

    init(
        category: String,
        userMessagePreview: String? = nil,
        isRetryable: Bool = false,
        httpStatus: Int? = nil
    ) {
        self.category = category
        self.userMessagePreview = userMessagePreview
        self.isRetryable = isRetryable
        self.httpStatus = httpStatus
    }
}

/// Health or Health Intelligence availability signal.
struct HealthAvailabilityPayload: Codable, Equatable, Sendable {
    var isAvailable: Bool
    var missingSignals: [String]
    var reason: String?
    var healthIntelligenceAwarenessAvailable: Bool?

    init(
        isAvailable: Bool,
        missingSignals: [String] = [],
        reason: String? = nil,
        healthIntelligenceAwarenessAvailable: Bool? = nil
    ) {
        self.isAvailable = isAvailable
        self.missingSignals = missingSignals
        self.reason = reason
        self.healthIntelligenceAwarenessAvailable = healthIntelligenceAwarenessAvailable
    }
}

/// AI context assembly metadata (not the full context body).
struct ContextGenerationPayload: Codable, Equatable, Sendable {
    var lookbackDays: Int?
    var timelineEventCount: Int?
    var recentMessageCount: Int?
    var hasTodaySummary: Bool
    var hasHealthIntelligence: Bool
    var healthIntelligenceAwarenessAvailable: Bool
    var contextByteEstimate: Int?
    var trigger: String?

    init(
        lookbackDays: Int? = nil,
        timelineEventCount: Int? = nil,
        recentMessageCount: Int? = nil,
        hasTodaySummary: Bool = false,
        hasHealthIntelligence: Bool = false,
        healthIntelligenceAwarenessAvailable: Bool = false,
        contextByteEstimate: Int? = nil,
        trigger: String? = nil
    ) {
        self.lookbackDays = lookbackDays
        self.timelineEventCount = timelineEventCount
        self.recentMessageCount = recentMessageCount
        self.hasTodaySummary = hasTodaySummary
        self.hasHealthIntelligence = hasHealthIntelligence
        self.healthIntelligenceAwarenessAvailable = healthIntelligenceAwarenessAvailable
        self.contextByteEstimate = contextByteEstimate
        self.trigger = trigger
    }
}

/// Undo of a recent Coach mutation.
struct UndoPerformedPayload: Codable, Equatable, Sendable {
    /// Entry type label: `food`, `water`, `weight`, `workout`.
    var entryType: String
    var undoneEntryId: UUID?
    var summary: String?

    init(entryType: String, undoneEntryId: UUID? = nil, summary: String? = nil) {
        self.entryType = entryType
        self.undoneEntryId = undoneEntryId
        self.summary = summary
    }
}

/// Lightweight marker for system refresh events.
struct SystemRefreshPayload: Codable, Equatable, Sendable {
    var reason: String?

    init(reason: String? = nil) {
        self.reason = reason
    }
}

// MARK: - Discriminated payload union

/// Type-safe structured payload for a `CoachTimelineEvent`.
enum CoachTimelineEventPayload: Equatable, Sendable {

    /// Discriminator for encoding and payload-expectation helpers.
    enum Kind: Equatable, Sendable {
        case message
        case foodEstimate
        case foodLogged
        case waterLogged
        case weightLogged
        case workoutDetected
        case steps
        case photo
        case confirmation
        case error
        case healthAvailability
        case contextGeneration
        case undo
        case systemRefresh
        case empty
    }

    case message(MessagePayload)
    case foodEstimate(FoodEstimatePayload)
    case foodLogged(FoodLoggedPayload)
    case waterLogged(WaterLoggedPayload)
    case weightLogged(WeightLoggedPayload)
    case workoutDetected(WorkoutDetectedPayload)
    case steps(StepsPayload)
    case photo(PhotoPayload)
    case confirmation(ConfirmationPayload)
    case error(ErrorPayload)
    case healthAvailability(HealthAvailabilityPayload)
    case contextGeneration(ContextGenerationPayload)
    case undo(UndoPerformedPayload)
    case systemRefresh(SystemRefreshPayload)
    case empty

    var kind: Kind {
        switch self {
        case .message: return .message
        case .foodEstimate: return .foodEstimate
        case .foodLogged: return .foodLogged
        case .waterLogged: return .waterLogged
        case .weightLogged: return .weightLogged
        case .workoutDetected: return .workoutDetected
        case .steps: return .steps
        case .photo: return .photo
        case .confirmation: return .confirmation
        case .error: return .error
        case .healthAvailability: return .healthAvailability
        case .contextGeneration: return .contextGeneration
        case .undo: return .undo
        case .systemRefresh: return .systemRefresh
        case .empty: return .empty
        }
    }
}

// MARK: - Codable

extension CoachTimelineEventPayload: Codable {

    private enum CodingKeys: String, CodingKey {
        case kind
        case message
        case foodEstimate
        case foodLogged
        case waterLogged
        case weightLogged
        case workoutDetected
        case steps
        case photo
        case confirmation
        case error
        case healthAvailability
        case contextGeneration
        case undo
        case systemRefresh
    }

    private enum CodingKind: String, Codable {
        case message
        case foodEstimate
        case foodLogged
        case waterLogged
        case weightLogged
        case workoutDetected
        case steps
        case photo
        case confirmation
        case error
        case healthAvailability
        case contextGeneration
        case undo
        case systemRefresh
        case empty
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(CodingKind.self, forKey: .kind)

        switch kind {
        case .message:
            self = .message(try container.decode(MessagePayload.self, forKey: .message))
        case .foodEstimate:
            self = .foodEstimate(try container.decode(FoodEstimatePayload.self, forKey: .foodEstimate))
        case .foodLogged:
            self = .foodLogged(try container.decode(FoodLoggedPayload.self, forKey: .foodLogged))
        case .waterLogged:
            self = .waterLogged(try container.decode(WaterLoggedPayload.self, forKey: .waterLogged))
        case .weightLogged:
            self = .weightLogged(try container.decode(WeightLoggedPayload.self, forKey: .weightLogged))
        case .workoutDetected:
            self = .workoutDetected(try container.decode(WorkoutDetectedPayload.self, forKey: .workoutDetected))
        case .steps:
            self = .steps(try container.decode(StepsPayload.self, forKey: .steps))
        case .photo:
            self = .photo(try container.decode(PhotoPayload.self, forKey: .photo))
        case .confirmation:
            self = .confirmation(try container.decode(ConfirmationPayload.self, forKey: .confirmation))
        case .error:
            self = .error(try container.decode(ErrorPayload.self, forKey: .error))
        case .healthAvailability:
            self = .healthAvailability(try container.decode(HealthAvailabilityPayload.self, forKey: .healthAvailability))
        case .contextGeneration:
            self = .contextGeneration(try container.decode(ContextGenerationPayload.self, forKey: .contextGeneration))
        case .undo:
            self = .undo(try container.decode(UndoPerformedPayload.self, forKey: .undo))
        case .systemRefresh:
            self = .systemRefresh(try container.decode(SystemRefreshPayload.self, forKey: .systemRefresh))
        case .empty:
            self = .empty
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .message(let payload):
            try container.encode(CodingKind.message, forKey: .kind)
            try container.encode(payload, forKey: .message)
        case .foodEstimate(let payload):
            try container.encode(CodingKind.foodEstimate, forKey: .kind)
            try container.encode(payload, forKey: .foodEstimate)
        case .foodLogged(let payload):
            try container.encode(CodingKind.foodLogged, forKey: .kind)
            try container.encode(payload, forKey: .foodLogged)
        case .waterLogged(let payload):
            try container.encode(CodingKind.waterLogged, forKey: .kind)
            try container.encode(payload, forKey: .waterLogged)
        case .weightLogged(let payload):
            try container.encode(CodingKind.weightLogged, forKey: .kind)
            try container.encode(payload, forKey: .weightLogged)
        case .workoutDetected(let payload):
            try container.encode(CodingKind.workoutDetected, forKey: .kind)
            try container.encode(payload, forKey: .workoutDetected)
        case .steps(let payload):
            try container.encode(CodingKind.steps, forKey: .kind)
            try container.encode(payload, forKey: .steps)
        case .photo(let payload):
            try container.encode(CodingKind.photo, forKey: .kind)
            try container.encode(payload, forKey: .photo)
        case .confirmation(let payload):
            try container.encode(CodingKind.confirmation, forKey: .kind)
            try container.encode(payload, forKey: .confirmation)
        case .error(let payload):
            try container.encode(CodingKind.error, forKey: .kind)
            try container.encode(payload, forKey: .error)
        case .healthAvailability(let payload):
            try container.encode(CodingKind.healthAvailability, forKey: .kind)
            try container.encode(payload, forKey: .healthAvailability)
        case .contextGeneration(let payload):
            try container.encode(CodingKind.contextGeneration, forKey: .kind)
            try container.encode(payload, forKey: .contextGeneration)
        case .undo(let payload):
            try container.encode(CodingKind.undo, forKey: .kind)
            try container.encode(payload, forKey: .undo)
        case .systemRefresh(let payload):
            try container.encode(CodingKind.systemRefresh, forKey: .kind)
            try container.encode(payload, forKey: .systemRefresh)
        case .empty:
            try container.encode(CodingKind.empty, forKey: .kind)
        }
    }
}

// MARK: - Payload expectations

extension CoachTimelineEventType {

    /// Suggested default payload shape for each event type (documentation + validation helpers).
    var expectedPayloadKind: CoachTimelineEventPayload.Kind {
        switch self {
        case .userMessage, .assistantMessage, .clarificationAsked, .clarificationAnswered:
            return .message
        case .foodEstimateCreated:
            return .foodEstimate
        case .foodLogged, .foodEdited, .foodDeleted:
            return .foodLogged
        case .foodRejected:
            return .foodEstimate
        case .waterLogged:
            return .waterLogged
        case .weightLogged:
            return .weightLogged
        case .workoutDetected:
            return .workoutDetected
        case .stepsUpdated:
            return .steps
        case .photoAttached, .photoAnalysisStarted, .photoAnalysisCompleted, .photoAnalysisFailed:
            return .photo
        case .pendingConfirmationCreated, .pendingConfirmationConfirmed, .pendingConfirmationRejected:
            return .confirmation
        case .undoPerformed:
            return .undo
        case .backendError, .authError:
            return .error
        case .systemRefresh:
            return .systemRefresh
        case .healthDataUnavailable:
            return .healthAvailability
        case .contextGenerated:
            return .contextGeneration
        case .unknown:
            return .empty
        }
    }
}
