//
//  CoachImageAnalysisDebugLogger.swift
//  Fitness Coach
//
//  DEBUG-only safe diagnostics for Coach meal image analysis.
//  Never logs raw image bytes, base64, user text, tokens, or provider secrets.
//

import Foundation
import OSLog

struct CoachImageAnalysisDebugContext: Equatable, Sendable {
    var sessionId: UUID?
    var userMessageId: UUID?
    var source: CoachInputAttachmentSource?
    var mimeType: String?
    var rawBytes: Int?
    var compressedBytes: Int?
    var base64Chars: Int?
    var attempt: Int?
    var isRetry: Bool?
    var isRecommission: Bool?
    var hasCaption: Bool?
    var hasClarification: Bool?
    var hasPreviousAnalysis: Bool?
    var backendStatus: Int?
    var durationMs: Int?
    var responseBytes: Int?
    var parseSuccess: Bool?
    var itemCount: Int?
    var summaryLength: Int?
    var confidence: String?
    var sessionStatus: String?
    var errorCategory: String?
    var validationErrorCount: Int?
}

enum CoachImageAnalysisDebugLogFormatter {

    static func sourceLabel(_ source: CoachInputAttachmentSource) -> String {
        switch source {
        case .camera: return "camera"
        case .library: return "library"
        }
    }

    static func errorCategory(for error: Error) -> String {
        if let serviceError = error as? AIServiceError {
            return errorCategory(for: serviceError)
        }
        if let clientError = error as? LLMClientError {
            return errorCategory(for: clientError)
        }
        if let photoError = error as? CoachMealPhotoError {
            return errorCategory(for: photoError)
        }
        return "unknown"
    }

    static func errorCategory(for error: CoachMealPhotoError) -> String {
        switch error {
        case .userCancelled: return "user_cancelled"
        case .noImage: return "no_image"
        case .loadFailed: return "load_failed"
        case .encodingFailed: return "encoding_failed"
        }
    }

    static func errorCategory(for error: AIServiceError) -> String {
        switch error {
        case .authenticationFailed: return "authentication"
        case .networkUnavailable: return "network"
        case .requestTimedOut: return "timeout"
        case .payloadTooLarge: return "payload_too_large"
        case .imageEncodingFailed: return "image_encoding"
        case .backendRejectedImage: return "backend_rejected_image"
        case .modelUnavailable: return "model_unavailable"
        case .backendUnavailable: return "backend_unavailable"
        case .invalidNutritionJSON: return "invalid_nutrition_json"
        case .parsingFailed, .decodingFailed: return "parse_failure"
        case .validationFailed, .invalidResponse: return "validation"
        case .requestFailed: return "request_failed"
        case .featureDisabled: return "feature_disabled"
        }
    }

    static func errorCategory(for error: LLMClientError) -> String {
        switch error {
        case .invalidURL: return "invalid_url"
        case .missingConfiguration: return "missing_configuration"
        case .authenticationFailed: return "authentication"
        case .networkUnavailable: return "network"
        case .requestTimedOut: return "timeout"
        case .payloadTooLarge: return "payload_too_large"
        case .backendRejected: return "backend_rejected"
        case .rateLimited: return "rate_limited"
        case .modelUnavailable: return "model_unavailable"
        case .backendUnavailable: return "backend_unavailable"
        case .decodingFailed: return "parse_failure"
        case .invalidStatusCode: return "http_status"
        case .requestFailed: return "request_failed"
        }
    }

    static func fields(from context: CoachImageAnalysisDebugContext) -> [String: String] {
        var fields: [String: String] = [:]
        if let sessionId = context.sessionId {
            fields["sessionId"] = sessionId.uuidString
        }
        if let userMessageId = context.userMessageId {
            fields["userMessageId"] = userMessageId.uuidString
        }
        if let source = context.source {
            fields["source"] = sourceLabel(source)
        }
        if let mimeType = context.mimeType {
            fields["mimeType"] = mimeType
        }
        if let rawBytes = context.rawBytes {
            fields["rawBytes"] = String(rawBytes)
        }
        if let compressedBytes = context.compressedBytes {
            fields["compressedBytes"] = String(compressedBytes)
        }
        if let base64Chars = context.base64Chars {
            fields["base64Chars"] = String(base64Chars)
        }
        if let attempt = context.attempt {
            fields["attempt"] = String(attempt)
        }
        if let isRetry = context.isRetry {
            fields["isRetry"] = String(isRetry)
        }
        if let isRecommission = context.isRecommission {
            fields["isRecommission"] = String(isRecommission)
        }
        if let hasCaption = context.hasCaption {
            fields["hasCaption"] = String(hasCaption)
        }
        if let hasClarification = context.hasClarification {
            fields["hasClarification"] = String(hasClarification)
        }
        if let hasPreviousAnalysis = context.hasPreviousAnalysis {
            fields["hasPreviousAnalysis"] = String(hasPreviousAnalysis)
        }
        if let backendStatus = context.backendStatus {
            fields["backendStatus"] = String(backendStatus)
        }
        if let durationMs = context.durationMs {
            fields["durationMs"] = String(durationMs)
        }
        if let responseBytes = context.responseBytes {
            fields["responseBytes"] = String(responseBytes)
        }
        if let parseSuccess = context.parseSuccess {
            fields["parseSuccess"] = String(parseSuccess)
        }
        if let itemCount = context.itemCount {
            fields["itemCount"] = String(itemCount)
        }
        if let summaryLength = context.summaryLength {
            fields["summaryLength"] = String(summaryLength)
        }
        if let confidence = context.confidence {
            fields["confidence"] = confidence
        }
        if let sessionStatus = context.sessionStatus {
            fields["sessionStatus"] = sessionStatus
        }
        if let errorCategory = context.errorCategory {
            fields["errorCategory"] = errorCategory
        }
        if let validationErrorCount = context.validationErrorCount {
            fields["validationErrorCount"] = String(validationErrorCount)
        }
        return fields
    }

    static func redactSensitiveJSONFields(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: #"Bearer\s+\S+"#, with: "Bearer <redacted>", options: .regularExpression)
            .replacingOccurrences(
                of: #""Authorization"\s*:\s*"[^"]*""#,
                with: "\"Authorization\":\"<redacted>\"",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #""base64"\s*:\s*"[^"]*""#,
                with: "\"base64\":\"<redacted>\"",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #""message"\s*:\s*"[^"]*""#,
                with: "\"message\":\"<redacted>\"",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #""clarification"\s*:\s*"[^"]*""#,
                with: "\"clarification\":\"<redacted>\"",
                options: .regularExpression
            )
    }
}

enum CoachImageAnalysisDebugLogger {

    static func logImageSelected(
        source: CoachInputAttachmentSource,
        rawBytes: Int,
        compressedBytes: Int,
        mimeType: String = "image/jpeg"
    ) {
        emit(
            message: "Meal image selected",
            context: CoachImageAnalysisDebugContext(
                source: source,
                mimeType: mimeType,
                rawBytes: rawBytes,
                compressedBytes: compressedBytes
            )
        )
    }

    static func logAnalysisStarted(
        sessionId: UUID,
        userMessageId: UUID,
        attempt: Int,
        isRetry: Bool,
        isRecommission: Bool,
        hasCaption: Bool,
        compressedBytes: Int,
        mimeType: String = "image/jpeg"
    ) {
        emit(
            message: "Image analysis request started",
            context: CoachImageAnalysisDebugContext(
                sessionId: sessionId,
                userMessageId: userMessageId,
                mimeType: mimeType,
                compressedBytes: compressedBytes,
                attempt: attempt,
                isRetry: isRetry,
                isRecommission: isRecommission,
                hasCaption: hasCaption
            )
        )
    }

    static func logGatewayRequestStarted(
        mimeType: String,
        compressedBytes: Int,
        base64Chars: Int,
        hasCaption: Bool,
        hasClarification: Bool,
        hasPreviousAnalysis: Bool
    ) {
        emit(
            message: "analyze-meal-image gateway request started",
            context: CoachImageAnalysisDebugContext(
                mimeType: mimeType,
                compressedBytes: compressedBytes,
                base64Chars: base64Chars,
                hasCaption: hasCaption,
                hasClarification: hasClarification,
                hasPreviousAnalysis: hasPreviousAnalysis
            )
        )
    }

    static func logBackendResponse(
        status: Int,
        durationMs: Int,
        responseBytes: Int,
        success: Bool,
        errorCategory: String? = nil
    ) {
        emit(
            message: success ?
                "analyze-meal-image backend response received" :
                "analyze-meal-image backend response failed",
            context: CoachImageAnalysisDebugContext(
                backendStatus: status,
                durationMs: durationMs,
                responseBytes: responseBytes,
                parseSuccess: success,
                errorCategory: errorCategory
            )
        )
    }

    static func logResponseParsed(
        success: Bool,
        itemCount: Int? = nil,
        summaryLength: Int? = nil,
        errorCategory: String? = nil,
        validationErrorCount: Int? = nil
    ) {
        emit(
            message: success ?
                "Meal image response parsed successfully" :
                "Meal image response parse failed",
            context: CoachImageAnalysisDebugContext(
                parseSuccess: success,
                itemCount: itemCount,
                summaryLength: summaryLength,
                errorCategory: errorCategory,
                validationErrorCount: validationErrorCount
            )
        )
    }

    static func logSessionOutcome(
        sessionId: UUID,
        attempt: Int,
        sessionStatus: String,
        confidence: String? = nil,
        itemCount: Int? = nil,
        errorCategory: String? = nil
    ) {
        emit(
            message: errorCategory == nil ?
                "Image analysis session completed" :
                "Image analysis session failed",
            context: CoachImageAnalysisDebugContext(
                sessionId: sessionId,
                attempt: attempt,
                itemCount: itemCount,
                confidence: confidence,
                sessionStatus: sessionStatus,
                errorCategory: errorCategory
            )
        )
    }

    static func logError(_ error: Error, sessionId: UUID? = nil, attempt: Int? = nil) {
        emit(
            message: "Image analysis error",
            context: CoachImageAnalysisDebugContext(
                sessionId: sessionId,
                attempt: attempt,
                errorCategory: CoachImageAnalysisDebugLogFormatter.errorCategory(for: error)
            )
        )
    }

    // MARK: - Private

    private static func emit(message: String, context: CoachImageAnalysisDebugContext) {
        #if DEBUG
        guard isEnabled else { return }
        let fields = CoachImageAnalysisDebugLogFormatter.fields(from: context)
        logger.debug("\(message, privacy: .public)")
        for (key, value) in fields.sorted(by: { $0.key < $1.key }) {
            logger.debug("\(key, privacy: .public)=\(value, privacy: .public)")
        }
        FormaPipelineTracer.event(
            stage: .mealImageAnalysis,
            level: .debug,
            message: message,
            fields: fields
        )
        #endif
    }

    #if DEBUG
    private static let logger = Logger(subsystem: "Forma", category: "CoachImageAnalysis")

    /// Disable with `FORMA_COACH_IMAGE_ANALYSIS_DEBUG=0`.
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["FORMA_COACH_IMAGE_ANALYSIS_DEBUG"] != "0"
    }
    #endif
}
