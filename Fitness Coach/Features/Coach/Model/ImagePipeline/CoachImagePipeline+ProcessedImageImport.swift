//
//  CoachImagePipeline+ProcessedImageImport.swift
//  Fitness Coach
//
//  Forma — Shared processed-image payload for camera and photo-library imports.
//

import Foundation

extension CoachImagePipeline {

    struct ProcessedImageImport: Equatable, Sendable {
        let processed: CoachProcessedImage
        let originalEstimatedBytes: Int?

        init(processed: CoachProcessedImage, originalEstimatedBytes: Int?) {
            self.processed = processed
            self.originalEstimatedBytes = originalEstimatedBytes
        }
    }

    /// Backward-compatible alias for photo-library imports.
    typealias PhotoLibraryImport = ProcessedImageImport
}
