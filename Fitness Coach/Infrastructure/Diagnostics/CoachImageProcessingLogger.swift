//
//  CoachImageProcessingLogger.swift
//  Fitness Coach
//
//  Safe analytics/debug logging for Coach image processing.
//  Never logs image bytes, EXIF, location, or other image content.
//

import Foundation
import OSLog

/// Scalar analytics payload for Coach image compression (no image content).
struct CoachImageProcessingAnalyticsEvent: Equatable, Sendable {
    let imageSource: String
    let originalWidth: Int?
    let originalHeight: Int?
    let processedWidth: Int?
    let processedHeight: Int?
    let finalByteSize: Int?
    let compressionStrategy: String?
    let processingDurationMs: Int
    let success: Bool
    let failureReason: String?

    var fields: [String: String] {
        var result: [String: String] = [
            "image_source": imageSource,
            "processing_duration_ms": String(processingDurationMs),
            "success": String(success)
        ]

        if let originalWidth {
            result["original_width"] = String(originalWidth)
        }
        if let originalHeight {
            result["original_height"] = String(originalHeight)
        }
        if let processedWidth {
            result["processed_width"] = String(processedWidth)
        }
        if let processedHeight {
            result["processed_height"] = String(processedHeight)
        }
        if let finalByteSize {
            result["final_byte_size"] = String(finalByteSize)
        }
        if let compressionStrategy {
            result["compression_strategy"] = compressionStrategy
        }
        if let failureReason {
            result["failure_reason"] = failureReason
        }

        return result
    }
}

enum CoachImageProcessingLogger {

    static func logPipelineSuccess(
        source: CoachInputAttachmentSource,
        processed: CoachProcessedImage,
        processingDurationMs: Int
    ) {
        emit(
            message: "Coach image processing succeeded",
            event: CoachImageProcessingAnalyticsEvent(
                imageSource: analyticsSourceLabel(source),
                originalWidth: processed.originalPixelSize.width,
                originalHeight: processed.originalPixelSize.height,
                processedWidth: processed.processedPixelSize.width,
                processedHeight: processed.processedPixelSize.height,
                finalByteSize: processed.finalByteSize,
                compressionStrategy: processed.compressionStrategy.rawValue,
                processingDurationMs: processingDurationMs,
                success: true,
                failureReason: nil
            )
        )
    }

    static func logPipelineFailure(
        source: CoachInputAttachmentSource,
        originalSize: CoachImagePixelSize?,
        error: CoachImagePipelineError,
        processingDurationMs: Int
    ) {
        emit(
            message: "Coach image processing failed",
            event: CoachImageProcessingAnalyticsEvent(
                imageSource: analyticsSourceLabel(source),
                originalWidth: originalSize?.width,
                originalHeight: originalSize?.height,
                processedWidth: nil,
                processedHeight: nil,
                finalByteSize: nil,
                compressionStrategy: nil,
                processingDurationMs: processingDurationMs,
                success: false,
                failureReason: failureReason(for: error)
            )
        )
    }

    static func logSelectionFailure(
        source: CoachInputAttachmentSource,
        originalSize: CoachImagePixelSize?,
        error: CoachMealPhotoError,
        processingDurationMs: Int = 0
    ) {
        emit(
            message: "Coach image selection processing failed",
            event: CoachImageProcessingAnalyticsEvent(
                imageSource: analyticsSourceLabel(source),
                originalWidth: originalSize?.width,
                originalHeight: originalSize?.height,
                processedWidth: nil,
                processedHeight: nil,
                finalByteSize: nil,
                compressionStrategy: nil,
                processingDurationMs: processingDurationMs,
                success: false,
                failureReason: failureReason(for: error)
            )
        )
    }

    static func analyticsSourceLabel(_ source: CoachInputAttachmentSource) -> String {
        switch source {
        case .camera:
            return "camera"
        case .library:
            return "photo_library"
        }
    }

    static func failureReason(for error: CoachImagePipelineError) -> String {
        CoachImageAnalysisDebugLogFormatter.errorCategory(for: error)
    }

    static func failureReason(for error: CoachMealPhotoError) -> String {
        CoachImageAnalysisDebugLogFormatter.errorCategory(for: error)
    }

    // MARK: - Private

    private static func emit(message: String, event: CoachImageProcessingAnalyticsEvent) {
        #if DEBUG
        guard isEnabled else { return }
        let fields = event.fields
        logger.debug("\(message, privacy: .public)")
        for (key, value) in fields.sorted(by: { $0.key < $1.key }) {
            logger.debug("\(key, privacy: .public)=\(value, privacy: .public)")
        }
        FormaPipelineTracer.event(
            stage: .mealImageProcessing,
            level: event.success ? .info : .warn,
            message: message,
            fields: fields
        )
        #endif
    }

    #if DEBUG
    private static let logger = Logger(subsystem: "Forma", category: "CoachImageProcessing")

    /// Disable with `FORMA_COACH_IMAGE_PROCESSING_DEBUG=0`.
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["FORMA_COACH_IMAGE_PROCESSING_DEBUG"] != "0"
    }
    #endif
}
