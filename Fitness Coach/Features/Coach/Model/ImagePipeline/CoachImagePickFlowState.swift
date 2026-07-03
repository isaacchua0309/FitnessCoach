//
//  CoachImagePickFlowState.swift
//  Fitness Coach
//
//  Forma — UI state machine for Coach meal-photo pick and pipeline processing.
//

import Foundation

enum CoachImagePickSource: Equatable, Sendable {
    case camera
    case library
}

enum CoachImagePickFlowState: Equatable, Sendable {
    case idle
    case requestingPermission(CoachImagePickSource)
    case pickerPresented(CoachImagePickSource)
    case processingImage(CoachImagePickSource)
    case imageReady
    case failed(CoachMealPhotoError)

    var isBusy: Bool {
        switch self {
        case .idle, .imageReady, .failed:
            return false
        case .requestingPermission, .pickerPresented, .processingImage:
            return true
        }
    }

    var isProcessingImage: Bool {
        if case .processingImage = self { return true }
        return false
    }

    var activeSource: CoachImagePickSource? {
        switch self {
        case .idle, .imageReady, .failed:
            return nil
        case .requestingPermission(let source),
             .pickerPresented(let source),
             .processingImage(let source):
            return source
        }
    }
}
