//
//  CoachImagePipeline+PhotoLibrary.swift
//  Fitness Coach
//
//  Forma — Photo library import path for CoachImagePipeline.
//

import PhotosUI
import UIKit

extension CoachImagePipeline {

    /// Loads a `UIImage` from the photo library, then processes it for Coach upload.
    static func importFromPhotoLibrary(
        _ item: PhotosPickerItem,
        localReferenceID: UUID = UUID(),
        config: CoachImageProcessingConfig = .default
    ) async -> Result<ProcessedImageImport, CoachMealPhotoError> {
        switch await loadImageFromPhotoLibrary(item) {
        case .failure(let error):
            return .failure(error)
        case .success(let loaded):
            return await processImportedImage(
                loaded.image,
                originalEstimatedBytes: loaded.originalEstimatedBytes,
                localReferenceID: localReferenceID,
                config: config
            )
        }
    }
}

extension CoachImagePipelineError {

    var mealPhotoError: CoachMealPhotoError {
        switch self {
        case .invalidInput:
            return .noImage
        case .encodingFailed, .exceedsMaxSize:
            return .encodingFailed
        }
    }
}
