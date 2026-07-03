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
        config: CoachImageProcessingConfig = .default
    ) async -> Result<ProcessedImageImport, CoachMealPhotoError> {
        do {
            let rawData: Data?
            if let transfer = try await item.loadTransferable(type: CoachPhotoPickerTransfer.self) {
                rawData = transfer.data
            } else if let data = try await item.loadTransferable(type: Data.self) {
                rawData = data
            } else {
                return .failure(.noImage)
            }

            guard let rawData, !rawData.isEmpty else {
                return .failure(.noImage)
            }

            guard let image = UIImage(data: rawData) else {
                return .failure(.loadFailed)
            }

            let originalEstimatedBytes = rawData.count
            let pipelineResult = await processAsync(image: image, config: config)

            switch pipelineResult {
            case .success(let processed):
            return .success(
                ProcessedImageImport(
                    processed: processed,
                    originalEstimatedBytes: originalEstimatedBytes,
                    localReferenceID: UUID()
                )
            )
            case .failure(let error):
                return .failure(error.mealPhotoError)
            }
        } catch {
            return .failure(.loadFailed)
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
