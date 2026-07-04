//
//  CoachMealImageAIRequestBuilder.swift
//  Fitness Coach
//
//  Builds analyze-meal-image requests from pipeline-compressed upload bytes.
//

import Foundation

enum CoachMealImageAIRequestBuildError: Equatable, Error {
    case emptyUploadData
    case uploadExceedsMaxBytes(byteCount: Int, maxBytes: Int)
}

enum CoachMealImageAIRequestBuilder {

    static let defaultFilename = AIMealImagePayload.defaultUploadFilename

    static func uniqueFilename() -> String {
        "\(UUID().uuidString).jpg"
    }

    static func validate(
        _ attachment: CoachMealImageUploadAttachment,
        maxUploadBytes: Int = CoachImageUploadConfig.default.maxUploadBytes
    ) -> Result<Void, CoachMealImageAIRequestBuildError> {
        guard CoachMealPhotoPipeline.hasImagePayload(attachment.uploadData) else {
            return .failure(.emptyUploadData)
        }

        let byteCount = attachment.uploadData.count
        guard byteCount <= maxUploadBytes else {
            return .failure(.uploadExceedsMaxBytes(byteCount: byteCount, maxBytes: maxUploadBytes))
        }

        guard AIGatewayPayloadLimits.fitsImagePayload(attachment.uploadData) else {
            return .failure(.uploadExceedsMaxBytes(byteCount: byteCount, maxBytes: maxUploadBytes))
        }

        return .success(())
    }

    static func buildAnalysisRequest(
        attachment: CoachMealImageUploadAttachment,
        message: String?,
        clarification: String? = nil,
        previousAnalysis: AIMealImageAnalysisPreviousAnalysis? = nil
    ) -> Result<AIMealImageAnalysisRequest, CoachMealImageAIRequestBuildError> {
        validate(attachment).map {
            AIMealImageAnalysisRequest(
                message: message,
                image: AIMealImagePayload.fromCompressedUpload(
                    attachment.uploadData,
                    mimeType: attachment.mimeType,
                    filename: attachment.filename,
                    processedSize: attachment.processedSize
                ),
                clarification: clarification,
                previousAnalysis: previousAnalysis
            )
        }
    }

    static func mapBuildError(_ error: CoachMealImageAIRequestBuildError) -> AIServiceError {
        switch error {
        case .emptyUploadData, .uploadExceedsMaxBytes:
            // Recoverable local failure — not shown as "photo too large" unless compression failed.
            return .imageEncodingFailed
        }
    }
}
