//
//  CoachImagePickFlowController.swift
//  Fitness Coach
//
//  Forma — Coordinates camera/photo-library presentation and CoachImagePipeline processing.
//

import Combine
import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class CoachImagePickFlowController: ObservableObject {

    @Published private(set) var state: CoachImagePickFlowState = .idle
    @Published var isPhotoPickerPresented = false
    @Published var isCameraPresented = false

    /// Set before `fullScreenCover` dismiss runs so a delivered capture is not dropped.
    private var cameraDeliveredResult = false
    /// Set when `PhotosPicker` hands off an item before the dismiss callback runs.
    private var librarySelectionReceived = false

    var allowsAttachmentPick: Bool {
        !state.isBusy
    }

    var isProcessingImage: Bool {
        state.isProcessingImage
    }

    func handleAttachmentRemoved() {
        librarySelectionReceived = false
        state = .idle
    }

    func markLibrarySelectionReceived() {
        librarySelectionReceived = true
    }

    @discardableResult
    func beginPhotoLibraryPick(model: CoachModel) -> Bool {
        guard state == .idle else { return false }
        guard model.requestPhotoPick() else { return false }

        state = .pickerPresented(.library)
        isPhotoPickerPresented = true
        return true
    }

    func beginCameraPick(model: CoachModel) async {
        guard state == .idle else { return }
        guard model.requestPhotoPick() else { return }

        cameraDeliveredResult = false
        state = .requestingPermission(.camera)

        let permission = await CoachCameraAccess.resolveForCapture()
        guard state == .requestingPermission(.camera) else { return }

        switch permission {
        case .success:
            state = .pickerPresented(.camera)
            isCameraPresented = true
        case .failure(let error):
            await handleFailure(error, model: model, requiresActiveImport: false)
        }
    }

    func handlePhotoLibraryPickerDismissed() {
        guard case .pickerPresented(.library) = state else { return }
        if librarySelectionReceived {
            librarySelectionReceived = false
            return
        }
        state = .idle
        isPhotoPickerPresented = false
    }

    func handlePhotoLibrarySelection(
        _ item: PhotosPickerItem,
        model: CoachModel
    ) async {
        librarySelectionReceived = false
        guard case .pickerPresented(.library) = state else { return }

        isPhotoPickerPresented = false
        state = .processingImage(.library)
        model.beginPendingImageProcessing(source: .library)

        switch await CoachImagePipeline.loadImageFromPhotoLibrary(item) {
        case .failure(let error):
            CoachImageProcessingLogger.logSelectionFailure(source: .library, originalSize: nil, error: error)
            await handleFailure(error, model: model)
        case .success(let loaded):
            let localReferenceID = model.storePendingImageLocalSource(loaded.image)
            model.attachPendingImageLocalReference(localReferenceID)
            let importResult = await CoachImagePipeline.processImportedImage(
                loaded.image,
                source: .library,
                originalEstimatedBytes: loaded.originalEstimatedBytes,
                localReferenceID: localReferenceID
            )
            await completeImport(
                importResult,
                source: .library,
                model: model,
                localReferenceID: localReferenceID
            )
        }
    }

    func handleCameraResult(
        _ result: Result<UIImage, CoachMealPhotoError>,
        model: CoachModel
    ) async {
        cameraDeliveredResult = true
        defer { cameraDeliveredResult = false }
        isCameraPresented = false

        switch result {
        case .failure(.userCancelled):
            model.revertPendingImageProcessingCancel()
            if case .pickerPresented(.camera) = state {
                state = .idle
            }
            return
        case .failure(let error):
            await handleFailure(error, model: model)
            return
        case .success(let image):
            guard state == .pickerPresented(.camera) || state == .processingImage(.camera) else {
                return
            }
            state = .processingImage(.camera)
            model.beginPendingImageProcessing(source: .camera)
            let localReferenceID = model.storePendingImageLocalSource(image)
            model.attachPendingImageLocalReference(localReferenceID)
            let importResult = await CoachImagePipeline.importFromCamera(
                image,
                source: .camera,
                localReferenceID: localReferenceID
            )
            await completeImport(
                importResult,
                source: .camera,
                model: model,
                localReferenceID: localReferenceID
            )
        }
    }

    func retryFailedImageSelection(model: CoachModel) async {
        guard let error = model.inputState.imageError, error.supportsComposerRetry else { return }
        guard !model.inputState.isImageProcessing else { return }

        let source = model.inputState.pendingImage?.source ?? .library
        model.clearPendingImageError()

        if let localReferenceID = model.inputState.pendingImage?.localReferenceID,
           let image = model.pendingImageLocalSource(for: localReferenceID) {
            state = .processingImage(source == .camera ? .camera : .library)
            model.beginPendingImageProcessing(source: source)
            model.attachPendingImageLocalReference(localReferenceID)

            let originalEstimatedBytes = model.inputState.pendingImage?.originalEstimatedBytes
            let importResult = await CoachImagePipeline.processImportedImage(
                image,
                source: source,
                originalEstimatedBytes: originalEstimatedBytes,
                localReferenceID: localReferenceID
            )
            await completeImport(
                importResult,
                source: source,
                model: model,
                localReferenceID: localReferenceID
            )
            return
        }

        switch source {
        case .library:
            _ = beginPhotoLibraryPick(model: model)
        case .camera:
            await beginCameraPick(model: model)
        }
    }

    func handleCameraPickerDismissedWithoutResult() {
        guard !cameraDeliveredResult else { return }
        guard case .pickerPresented(.camera) = state else { return }
        state = .idle
        isCameraPresented = false
    }

    /// Dismisses any camera/photo-library UI when Coach is no longer the active tab.
    func dismissPresentedPickers() {
        librarySelectionReceived = false
        cameraDeliveredResult = false
        isPhotoPickerPresented = false
        isCameraPresented = false
        if case .pickerPresented = state {
            state = .idle
        }
    }

    private func completeImport(
        _ result: Result<CoachImagePipeline.ProcessedImageImport, CoachMealPhotoError>,
        source: CoachInputAttachmentSource,
        model: CoachModel,
        localReferenceID: UUID
    ) async {
        switch result {
        case .failure(.userCancelled):
            guard model.hasActivePendingImageImport() else {
                state = .idle
                return
            }
            model.revertPendingImageProcessingCancel()
            state = .idle
        case .failure(let error):
            await handleFailure(error, model: model)
        case .success(let imported):
            guard model.shouldAcceptImportSuccess(localReferenceID: localReferenceID) else {
                state = .idle
                return
            }
            let staged = await model.stagePipelineProcessedPhoto(imported, source: source)
            if staged {
                state = .imageReady
                state = .idle
            } else {
                state = .idle
            }
        }
    }

    private func handleFailure(
        _ error: CoachMealPhotoError,
        model: CoachModel,
        requiresActiveImport: Bool = true
    ) async {
        guard error != .userCancelled else {
            model.revertPendingImageProcessingCancel()
            state = .idle
            return
        }

        if requiresActiveImport, !model.hasActivePendingImageImport() {
            state = .idle
            return
        }

        state = .failed(error)
        model.failPendingImageProcessing(error)
        CoachImageAnalysisDebugLogger.logError(error)
        model.appendMealPhotoSelectionFailure(error)
        state = .idle
    }
}
