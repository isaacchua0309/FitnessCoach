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
    case cameraUnavailable
}
