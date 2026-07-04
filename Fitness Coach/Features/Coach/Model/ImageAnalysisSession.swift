//
//  ImageAnalysisSession.swift
//  Fitness Coach
//
//  Forma — State machine for meal-photo analysis, retry, and clarification recommission.
//

import Foundation

enum ImageAnalysisSessionStatus: Equatable, Sendable {
    case pending
    case analyzing
    case succeeded
    case failed
    case needsClarification
}

struct ImageAnalysisClarificationTurn: Equatable, Codable, Sendable {
    var question: String
    var answer: String?

    init(question: String, answer: String? = nil) {
        self.question = question
        self.answer = answer
    }
}

struct ImageAnalysisSessionResult: Equatable, Sendable {
    var mealDraft: FoodLogDraft
    var confidence: AIConfidence
    var summary: String
    var clarifyingQuestion: String?

    init(
        mealDraft: FoodLogDraft,
        confidence: AIConfidence,
        summary: String,
        clarifyingQuestion: String? = nil
    ) {
        self.mealDraft = mealDraft
        self.confidence = confidence
        self.summary = summary
        self.clarifyingQuestion = clarifyingQuestion
    }
}

struct ImageAnalysisSession: Equatable, Identifiable, Sendable {
    let sessionId: UUID
    let userMessageID: UUID
    let originalImageAttachment: ChatMessageImageAttachment
    var userCaption: String
    var status: ImageAnalysisSessionStatus
    var attempts: Int
    var latestResult: ImageAnalysisSessionResult?
    var latestError: String?
    var clarificationTurns: [ImageAnalysisClarificationTurn]
    var activeClarifyingQuestion: String?

    var id: UUID { sessionId }

    static func newSession(
        userMessageID: UUID,
        attachment: ChatMessageImageAttachment,
        userCaption: String
    ) -> ImageAnalysisSession {
        ImageAnalysisSession(
            sessionId: UUID(),
            userMessageID: userMessageID,
            originalImageAttachment: attachment,
            userCaption: userCaption,
            status: .pending,
            attempts: 0,
            latestResult: nil,
            latestError: nil,
            clarificationTurns: [],
            activeClarifyingQuestion: nil
        )
    }
}

enum ImageAnalysisSessionEvent: Equatable, Sendable {
    case analysisStarted
    case analysisSucceeded(ImageAnalysisSessionResult)
    case analysisFailed(String)
    case clarificationAnswered(String)
    case draftEdited(FoodLogDraft)
}

enum ImageAnalysisSessionReducer {

    static func apply(
        _ session: ImageAnalysisSession,
        event: ImageAnalysisSessionEvent
    ) -> ImageAnalysisSession {
        var next = session

        switch event {
        case .analysisStarted:
            next.attempts += 1
            next.status = .analyzing
            next.latestError = nil

        case .analysisSucceeded(let result):
            next.latestResult = result
            next.latestError = nil
            if shouldRequestClarification(for: result) {
                next.status = .needsClarification
                next.activeClarifyingQuestion = result.clarifyingQuestion ??
                    ImageAnalysisSessionCopy.defaultClarifyingQuestion(for: result.mealDraft)
                if let question = next.activeClarifyingQuestion {
                    appendClarificationTurn(question: question, to: &next)
                }
            } else {
                next.status = .succeeded
                next.activeClarifyingQuestion = nil
            }

        case .analysisFailed(let error):
            next.status = .failed
            next.latestError = error
            next.activeClarifyingQuestion = nil

        case .clarificationAnswered(let answer):
            guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return next
            }
            if var last = next.clarificationTurns.last, last.answer == nil {
                last.answer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                next.clarificationTurns[next.clarificationTurns.count - 1] = last
            } else if let question = next.activeClarifyingQuestion {
                next.clarificationTurns.append(
                    ImageAnalysisClarificationTurn(
                        question: question,
                        answer: answer.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                )
            }
            next.status = .analyzing
            next.activeClarifyingQuestion = nil

        case .draftEdited(let mealDraft):
            if var result = next.latestResult {
                result.mealDraft = mealDraft
                next.latestResult = result
            }
            if next.status == .succeeded {
                next.status = .needsClarification
                let question = ImageAnalysisSessionCopy.editFollowUpQuestion
                next.activeClarifyingQuestion = question
                appendClarificationTurn(question: question, to: &next)
            }
        }

        return next
    }

    static func shouldRequestClarification(for result: ImageAnalysisSessionResult) -> Bool {
        CoachFoodAmbiguityPolicy.photoSessionShouldClarify(result: result)
    }

    private static func appendClarificationTurn(
        question: String,
        to session: inout ImageAnalysisSession
    ) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if session.clarificationTurns.last?.question == trimmed {
            return
        }
        session.clarificationTurns.append(ImageAnalysisClarificationTurn(question: trimmed))
    }
}

enum ImageAnalysisSessionCopy {
    static let editFollowUpQuestion =
        "You edited the estimate. Reply with any extra detail about the photo and I'll refine it."

    static func defaultClarifyingQuestion(for mealDraft: FoodLogDraft) -> String {
        if mealDraft.isMultiComponent {
            return "I wasn't fully sure about every item. Which ingredient or portion should I adjust?"
        }
        return "I wasn't fully sure about this meal. What sauce, side, or portion size should I use?"
    }

    static func clarificationPrompt(_ question: String) -> String {
        question
    }

    static func recommissionAcknowledgement(_ answer: String) -> String {
        "Thanks — I'll refine the estimate using your photo and: \"\(answer)\"."
    }
}

struct ImageAnalysisRecommissionContext: Equatable, Sendable {
    var clarification: String
    var clarificationHistory: [ImageAnalysisClarificationTurn]
    var previousResult: ImageAnalysisSessionResult?
}

enum ImageAnalysisPromptBuilder {

    static func initialPrompt(caption: String) -> String {
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? CoachMealPhotoPipeline.defaultAnalysisPrompt : trimmed
    }

    static func recommissionMessage(
        session: ImageAnalysisSession,
        clarification: String
    ) -> String {
        var sections: [String] = []
        let caption = session.userCaption.trimmingCharacters(in: .whitespacesAndNewlines)
        if !caption.isEmpty {
            sections.append("Original caption: \(caption)")
        }

        if let result = session.latestResult {
            sections.append("Previous summary: \(result.summary)")
            sections.append(
                "Previous estimate: \(result.mealDraft.displayName) · \(result.mealDraft.totalCalories) kcal"
            )
            if !result.mealDraft.components.isEmpty {
                let itemLines = result.mealDraft.components.map { component in
                    let portion = [component.quantity.map(FoodEntryFormFormatter.formatOptionalDouble), component.unit]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    let portionSuffix = portion.isEmpty ? "" : " (\(portion))"
                    return "- \(component.name)\(portionSuffix): \(component.calories) kcal"
                }
                sections.append("Previous items:\n\(itemLines.joined(separator: "\n"))")
            }
        }

        let answeredTurns = session.clarificationTurns.filter {
            !$0.question.isEmpty && ($0.answer?.isEmpty == false)
        }
        if !answeredTurns.isEmpty {
            let history = answeredTurns.map { turn in
                "Q: \(turn.question)\nA: \(turn.answer ?? "")"
            }.joined(separator: "\n")
            sections.append("Clarification history:\n\(history)")
        }

        sections.append("New clarification: \(clarification)")
        sections.append("Refine the meal photo estimate using the same image and this clarification.")
        return sections.joined(separator: "\n\n")
    }
}

@MainActor
final class ImageAnalysisSessionStore {
    private var sessionsByUserMessageID: [UUID: ImageAnalysisSession] = [:]

    func session(forUserMessageID userMessageID: UUID) -> ImageAnalysisSession? {
        sessionsByUserMessageID[userMessageID]
    }

    func session(forSessionID sessionID: UUID) -> ImageAnalysisSession? {
        sessionsByUserMessageID.values.first { $0.sessionId == sessionID }
    }

    func upsert(_ session: ImageAnalysisSession) {
        sessionsByUserMessageID[session.userMessageID] = session
    }

    @discardableResult
    func apply(
        userMessageID: UUID,
        event: ImageAnalysisSessionEvent
    ) -> ImageAnalysisSession? {
        guard var session = sessionsByUserMessageID[userMessageID] else { return nil }
        session = ImageAnalysisSessionReducer.apply(session, event: event)
        sessionsByUserMessageID[userMessageID] = session
        return session
    }

    func sessionAwaitingClarification() -> ImageAnalysisSession? {
        sessionsByUserMessageID.values.first { $0.status == .needsClarification }
    }

    func clear(userMessageID: UUID) {
        sessionsByUserMessageID.removeValue(forKey: userMessageID)
    }
}
