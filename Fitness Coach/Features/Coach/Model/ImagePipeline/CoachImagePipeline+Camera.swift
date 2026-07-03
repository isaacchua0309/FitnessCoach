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
        config: CoachImageProcessingConfig = .default
    ) async -> Result<ProcessedImageImport, CoachMealPhotoError> {
        let pipelineResult = await processAsync(image: image, config: config)

        switch pipelineResult {
        case .success(let processed):
            return .success(
                ProcessedImageImport(
                    processed: processed,
                    originalEstimatedBytes: nil,
                    localReferenceID: UUID()
                )
            )
        case .failure(let error):
            return .failure(error.mealPhotoError)
        }
    }
}
