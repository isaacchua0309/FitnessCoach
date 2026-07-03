//
//  CoachImagePipelineError.swift
//  Fitness Coach
//
//  Forma — Errors surfaced by CoachImagePipeline.
//

import Foundation

enum CoachImagePipelineError: Equatable, Error, Sendable {
    case invalidInput
    case encodingFailed
    case exceedsMaxSize(maxBytes: Int)
}
