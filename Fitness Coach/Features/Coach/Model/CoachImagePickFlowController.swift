//
//  CoachImagePickFlowController.swift
//  Fitness Coach
//
//  Forma — Coordinates camera/photo-library presentation and CoachImagePipeline processing.
//

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

    func resetIfNeeded() {
        switch state {
        case .idle, .imageReady, .failed:
            state = .idle
        default:
            break
        }
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

        let importResult = await CoachImagePipeline.importFromPhotoLibrary(item)
        await completeImport(importResult, source: .library, model: model)
    }

    func handleCameraResult(
        _ result: Result<UIImage, CoachMealPhotoError>,
        model: CoachModel
    ) async {
        isCameraPresented = false

        switch result {
        case .failure(.userCancelled):
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
            let importResult = await CoachImagePipeline.importFromCamera(image)
            await completeImport(importResult, source: .camera, model: model)
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
            state = .idle
            return
        }

        state = .failed(error)
        CoachImageAnalysisDebugLogger.logError(error)
        model.appendMealPhotoSelectionFailure(error)
        state = .idle
    }
}
