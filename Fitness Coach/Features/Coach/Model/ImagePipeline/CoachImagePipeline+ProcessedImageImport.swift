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
        let localReferenceID: UUID

        init(
            processed: CoachProcessedImage,
            originalEstimatedBytes: Int?,
            localReferenceID: UUID = UUID()
        ) {
            self.processed = processed
            self.originalEstimatedBytes = originalEstimatedBytes
            self.localReferenceID = localReferenceID
        }
    }
}
