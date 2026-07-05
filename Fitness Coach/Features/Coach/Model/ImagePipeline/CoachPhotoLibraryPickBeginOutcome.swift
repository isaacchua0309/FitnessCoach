//
//  CoachPhotoLibraryPickBeginOutcome.swift
//  Fitness Coach
//
//  Result of attempting to present the photo library picker from Coach.
//

import Foundation

enum CoachPhotoLibraryPickBeginOutcome: Equatable {
    case started
    case rejectedFlowBusy
    case rejectedComposerImageProcessing
    case rejectedComposerSending
}
