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

    var allowsAttachmentPick: Bool {
        !state.isBusy
    }

    var isProcessingImage: Bool {
        state.isProcessingImage
    }

    func handleAttachmentRemoved() {
        state = .idle
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

        state = .requestingPermission(.camera)

        let permission = await CoachCameraAccess.resolveForCapture()
        guard state == .requestingPermission(.camera) else { return }

        switch permission {
        case .success:
            state = .pickerPresented(.camera)
            isCameraPresented = true
        case .failure(let error):
            await handleFailure(error, model: model)
        }
    }

    func handlePhotoLibraryPickerDismissed() {
        guard case .pickerPresented(.library) = state else { return }
        state = .idle
        isPhotoPickerPresented = false
    }

    func handlePhotoLibrarySelection(
        _ item: PhotosPickerItem,
        model: CoachModel
    ) async {
        guard state == .pickerPresented(.library) || state == .idle else { return }

        isPhotoPickerPresented = false
        state = .processingImage(.library)
        model.beginPendingImageProcessing(source: .library)

        switch await CoachImagePipeline.loadImageFromPhotoLibrary(item) {
        case .failure(let error):
            await handleFailure(error, model: model)
        case .success(let loaded):
            let localReferenceID = model.storePendingImageLocalSource(loaded.image)
            model.attachPendingImageLocalReference(localReferenceID)
            let importResult = await CoachImagePipeline.processImportedImage(
                loaded.image,
                originalEstimatedBytes: loaded.originalEstimatedBytes,
                localReferenceID: localReferenceID
            )
            await completeImport(importResult, source: .library, model: model)
        }
    }

    func handleCameraResult(
        _ result: Result<UIImage, CoachMealPhotoError>,
        model: CoachModel
    ) async {
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
                localReferenceID: localReferenceID
            )
            await completeImport(importResult, source: .camera, model: model)
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
                originalEstimatedBytes: originalEstimatedBytes,
                localReferenceID: localReferenceID
            )
            await completeImport(importResult, source: source, model: model)
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
        guard case .pickerPresented(.camera) = state else { return }
        state = .idle
        isCameraPresented = false
    }

    private func completeImport(
        _ result: Result<CoachImagePipeline.ProcessedImageImport, CoachMealPhotoError>,
        source: CoachInputAttachmentSource,
        model: CoachModel
    ) async {
        switch result {
        case .failure(.userCancelled):
            model.revertPendingImageProcessingCancel()
            state = .idle
        case .failure(let error):
            await handleFailure(error, model: model)
        case .success(let imported):
            let staged = await model.stagePipelineProcessedPhoto(imported, source: source)
            if staged {
                state = .imageReady
                state = .idle
            } else {
                state = .idle
            }
        }
    }

    private func handleFailure(_ error: CoachMealPhotoError, model: CoachModel) async {
        guard error != .userCancelled else {
            model.revertPendingImageProcessingCancel()
            state = .idle
            return
        }

        state = .failed(error)
        model.failPendingImageProcessing(error)
        CoachImageAnalysisDebugLogger.logError(error)
        model.appendMealPhotoSelectionFailure(error)
        state = .idle
    }

    #if DEBUG
    func setStateForTests(_ newState: CoachImagePickFlowState) {
        state = newState
    }

    func simulateProcessingFailure(_ error: CoachMealPhotoError, model: CoachModel) async {
        state = .processingImage(.camera)
        model.failPendingImageProcessing(error)
        state = .failed(error)
        state = .idle
    }

    func handleFailureForTests(_ error: CoachMealPhotoError, model: CoachModel) async {
        state = .failed(error)
        model.appendMealPhotoSelectionFailure(error)
        state = .idle
    }
    #endif
}
