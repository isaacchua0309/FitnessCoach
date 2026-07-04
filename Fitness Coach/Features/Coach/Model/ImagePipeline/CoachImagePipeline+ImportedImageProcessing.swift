//
//  CoachImagePipeline+ImportedImageProcessing.swift
//  Fitness Coach
//
//  Shared processing entry for camera and photo-library UIImage imports.
//

import PhotosUI
import UIKit

extension CoachImagePipeline {

    struct PhotoLibraryLoadedImage {
        let image: UIImage
        let originalEstimatedBytes: Int
    }

    static func loadImageFromPhotoLibrary(
        _ item: PhotosPickerItem
    ) async -> Result<PhotoLibraryLoadedImage, CoachMealPhotoError> {
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

            return .success(
                PhotoLibraryLoadedImage(
                    image: image,
                    originalEstimatedBytes: rawData.count
                )
            )
        } catch {
            return .failure(.loadFailed)
        }
    }

    static func processImportedImage(
        _ image: UIImage,
        source: CoachInputAttachmentSource,
        originalEstimatedBytes: Int?,
        localReferenceID: UUID,
        config: CoachImageProcessingConfig = .default
    ) async -> Result<ProcessedImageImport, CoachMealPhotoError> {
        let started = Date()
        let originalPixelSize = CoachImagePipelineEncoding.displayPixelSize(of: image)
        let pipelineResult = await processAsync(image: image, config: config)
        let durationMs = Int(Date().timeIntervalSince(started) * 1_000)

        switch pipelineResult {
        case .success(let processed):
            CoachImageProcessingLogger.logPipelineSuccess(
                source: source,
                processed: processed,
                processingDurationMs: durationMs
            )
            return .success(
                ProcessedImageImport(
                    processed: processed,
                    originalEstimatedBytes: originalEstimatedBytes,
                    localReferenceID: localReferenceID
                )
            )
        case .failure(let error):
            CoachImageProcessingLogger.logPipelineFailure(
                source: source,
                originalSize: originalPixelSize,
                error: error,
                processingDurationMs: durationMs
            )
            return .failure(error.mealPhotoError)
        }
    }
}
