//
//  CoachMealImageUploadAttachment.swift
//  Fitness Coach
//
//  Compressed upload payload for Coach meal-image AI requests.
//

import Foundation
import UIKit

/// Processed upload bytes and metadata sent to the AI gateway (never the original UIImage).
struct CoachMealImageUploadAttachment: Equatable, Sendable {
    let uploadData: Data
    let mimeType: String
    let filename: String
    let processedSize: CoachImagePixelSize?

    init(
        uploadData: Data,
        mimeType: String = CoachImageUploadConfig.default.mimeType,
        filename: String = CoachMealImageAIRequestBuilder.defaultFilename,
        processedSize: CoachImagePixelSize? = nil
    ) {
        self.uploadData = uploadData
        self.mimeType = mimeType
        self.filename = filename
        self.processedSize = processedSize
    }

    static func from(
        processed: CoachProcessedImage,
        filename: String? = nil
    ) -> CoachMealImageUploadAttachment {
        CoachMealImageUploadAttachment(
            uploadData: processed.uploadData,
            mimeType: processed.uploadMIMEType,
            filename: filename ?? CoachMealImageAIRequestBuilder.defaultFilename,
            processedSize: processed.processedPixelSize
        )
    }

    static func from(
        pending: CoachPendingImageState,
        filename: String? = nil
    ) -> CoachMealImageUploadAttachment? {
        guard pending.isReady else { return nil }
        return CoachMealImageUploadAttachment(
            uploadData: pending.uploadData,
            mimeType: pending.mimeType,
            filename: filename ?? CoachMealImageAIRequestBuilder.defaultFilename,
            processedSize: pending.processedSize
        )
    }

    static func fromUploadData(
        _ uploadData: Data,
        mimeType: String = CoachImageUploadConfig.default.mimeType,
        filename: String? = nil
    ) -> CoachMealImageUploadAttachment {
        CoachMealImageUploadAttachment(
            uploadData: uploadData,
            mimeType: mimeType,
            filename: filename ?? CoachMealImageAIRequestBuilder.defaultFilename,
            processedSize: Self.processedPixelSize(from: uploadData)
        )
    }

    static func processedPixelSize(from uploadData: Data) -> CoachImagePixelSize? {
        guard let image = UIImage(data: uploadData) else { return nil }
        return CoachImagePixelSize(
            width: Int(image.size.width * image.scale),
            height: Int(image.size.height * image.scale)
        )
    }
}
