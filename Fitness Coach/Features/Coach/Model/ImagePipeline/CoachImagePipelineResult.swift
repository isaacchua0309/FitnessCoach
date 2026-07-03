//
//  CoachImagePipelineResult.swift
//  Fitness Coach
//
//  Forma — Result wrapper for CoachImagePipeline processing.
//

import Foundation

enum CoachImagePipelineResult: Equatable, Sendable {
    case success(CoachProcessedImage)
    case failure(CoachImagePipelineError)

    var processedImage: CoachProcessedImage? {
        if case .success(let image) = self {
            return image
        }
        return nil
    }

    var error: CoachImagePipelineError? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}
