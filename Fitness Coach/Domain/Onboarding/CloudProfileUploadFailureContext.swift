//
//  CloudProfileUploadFailureContext.swift
//  Fitness Coach
//
//  Forma — Why a cloud profile upload retry is being attempted (Stage 8).
//

import Foundation

enum CloudProfileUploadFailureContext: Equatable, Sendable {
    case onboardingCompletion
    case reconcileUpload
    case conflictReplace
    case profileEdit

    var writeIntent: CloudProfileWriteIntent {
        switch self {
        case .onboardingCompletion, .reconcileUpload:
            return .newProfileInitialUpload
        case .conflictReplace:
            return .userConfirmedReplace
        case .profileEdit:
            return .ownedProfileUpdate
        }
    }
}
