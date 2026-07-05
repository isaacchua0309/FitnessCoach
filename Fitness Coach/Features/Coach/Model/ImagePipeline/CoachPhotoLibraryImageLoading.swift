//
//  CoachPhotoLibraryImageLoading.swift
//  Fitness Coach
//
//  Testable seam for loading a UIImage from a PhotosPicker selection.
//  Production uses the live pipeline adapter; unit tests inject a closure.
//

import PhotosUI
import UIKit

typealias CoachPhotoLibraryImageLoader = @Sendable (
    PhotosPickerItem
) async -> Result<CoachImagePipeline.PhotoLibraryLoadedImage, CoachMealPhotoError>

enum CoachPhotoLibraryImageLoading {
    /// Production adapter — reads bytes from `PhotosPickerItem` via `CoachImagePipeline`.
    static let live: CoachPhotoLibraryImageLoader = { item in
        await CoachImagePipeline.loadImageFromPhotoLibrary(item)
    }
}
