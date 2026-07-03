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
}
