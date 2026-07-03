//
//  CoachMealPhotoError.swift
//  Fitness Coach
//
//  Forma — Meal photo selection and analysis errors (non-shaming copy via CoachResponseBuilder).
//

import Foundation

enum CoachMealPhotoError: Equatable, Error {
    case userCancelled
    case noImage
    case loadFailed
    case encodingFailed
    case cameraUnavailable
    case cameraPermissionDenied

    /// Errors surfaced in the composer with a retry action (not as chat bubbles).
    var supportsComposerRetry: Bool {
        switch self {
        case .encodingFailed, .loadFailed, .noImage:
            return true
        case .userCancelled, .cameraUnavailable, .cameraPermissionDenied:
            return false
        }
    }
}
