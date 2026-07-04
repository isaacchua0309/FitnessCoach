//
//  CoachImagePipeline+Camera.swift
//  Fitness Coach
//
//  Forma — Camera capture import path for CoachImagePipeline.
//

import UIKit

extension CoachImagePipeline {

    /// Processes a captured `UIImage` for Coach upload (orientation normalized in-pipeline).
    static func importFromCamera(
        _ image: UIImage,
        source: CoachInputAttachmentSource = .camera,
        localReferenceID: UUID = UUID(),
        config: CoachImageProcessingConfig = .default
    ) async -> Result<ProcessedImageImport, CoachMealPhotoError> {
        await processImportedImage(
            image,
            source: source,
            originalEstimatedBytes: nil,
            localReferenceID: localReferenceID,
            config: config
        )
    }
}
