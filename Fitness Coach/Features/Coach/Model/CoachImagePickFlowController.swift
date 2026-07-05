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

typealias CoachPhotoLibraryImageLoader = @Sendable (
    PhotosPickerItem
) async -> Result<CoachImagePipeline.PhotoLibraryLoadedImage, CoachMealPhotoError>

@MainActor
final class CoachImagePickFlowController: ObservableObject {

    @Published private(set) var state: CoachImagePickFlowState = .idle
    @Published var isPhotoPickerPresented = false
    @Published var isCameraPresented = false

    /// Set before `fullScreenCover` dismiss runs so a delivered capture is not dropped.
    private var cameraDeliveredResult = false
    /// Set when `PhotosPicker` hands off an item before the dismiss callback runs.
    private var librarySelectionReceived = false

    private let photoLibraryImageLoader: CoachPhotoLibraryImageLoader

    #if DEBUG
    /// Test-only hook invoked after clearing `librarySelectionReceived` and before the picker-state guard.
    var debugPhotoLibrarySelectionEntryHook: (@MainActor () async -> Void)?
    #endif

    init(
        photoLibraryImageLoader: @escaping CoachPhotoLibraryImageLoader = { item in
            await CoachImagePipeline.loadImageFromPhotoLibrary(item)
        }
    ) {
        self.photoLibraryImageLoader = photoLibraryImageLoader
    }

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
        #if DEBUG
        CoachPhotoLibraryPickDebugLogger.log(
            event: "mark_library_selection_received",
            flowState: state,
            isPhotoPickerPresented: isPhotoPickerPresented,
            librarySelectionReceived: true
        )
        #endif
    }

    #if DEBUG
    func debugLibrarySelectionReceivedForLogging() -> Bool {
        librarySelectionReceived
    }
    #endif

    @discardableResult
    func beginPhotoLibraryPick(model: CoachModel) -> Bool {
        guard state == .idle else {
            #if DEBUG
            CoachPhotoLibraryPickDebugLogger.log(
                event: "begin_photo_library_pick_rejected_busy",
                flowState: state,
                isPhotoPickerPresented: isPhotoPickerPresented,
                librarySelectionReceived: librarySelectionReceived,
                guardPassed: false
            )
            #endif
            return false
        }
        guard model.requestPhotoPick() else {
            #if DEBUG
            CoachPhotoLibraryPickDebugLogger.log(
                event: "begin_photo_library_pick_rejected_composer",
                flowState: state,
                isPhotoPickerPresented: isPhotoPickerPresented,
                librarySelectionReceived: librarySelectionReceived,
                guardPassed: false
            )
            #endif
            return false
        }

        state = .pickerPresented(.library)
        isPhotoPickerPresented = true
        #if DEBUG
        CoachPhotoLibraryPickDebugLogger.log(
            event: "begin_photo_library_pick",
            flowState: state,
            isPhotoPickerPresented: isPhotoPickerPresented,
            librarySelectionReceived: librarySelectionReceived,
            guardPassed: true
        )
        #endif
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
            #if DEBUG
            CoachPhotoLibraryPickDebugLogger.log(
                event: "handle_photo_library_picker_dismissed_pending_selection",
                flowState: state,
                isPhotoPickerPresented: isPhotoPickerPresented,
                librarySelectionReceived: false
            )
            #endif
            return
        }

        state = .idle
        isPhotoPickerPresented = false
        #if DEBUG
        CoachPhotoLibraryPickDebugLogger.log(
            event: "handle_photo_library_picker_dismissed_reset_idle",
            flowState: state,
            isPhotoPickerPresented: isPhotoPickerPresented,
            librarySelectionReceived: librarySelectionReceived
        )
        #endif
    }

    func handlePhotoLibrarySelection(
        _ item: PhotosPickerItem,
        model: CoachModel
    ) async {
        #if DEBUG
        CoachPhotoLibraryPickDebugLogger.log(
            event: "handle_photo_library_selection_entered",
            flowState: state,
            isPhotoPickerPresented: isPhotoPickerPresented,
            librarySelectionReceived: librarySelectionReceived,
            hasSelectionItem: true
        )
        #endif

        librarySelectionReceived = false
        #if DEBUG
        if let debugPhotoLibrarySelectionEntryHook {
            await debugPhotoLibrarySelectionEntryHook()
        }
        #endif
        guard case .pickerPresented(.library) = state else {
            #if DEBUG
            CoachPhotoLibraryPickDebugLogger.log(
                event: "handle_photo_library_selection_guard_failed",
                flowState: state,
                isPhotoPickerPresented: isPhotoPickerPresented,
                librarySelectionReceived: librarySelectionReceived,
                hasSelectionItem: true,
                guardPassed: false
            )
            #endif
            return
        }

        isPhotoPickerPresented = false
        state = .processingImage(.library)
        let beganPendingProcessing = model.beginPendingImageProcessing(source: .library)
        #if DEBUG
        CoachPhotoLibraryPickDebugLogger.log(
            event: "handle_photo_library_selection_processing",
            flowState: state,
            isPhotoPickerPresented: isPhotoPickerPresented,
            librarySelectionReceived: librarySelectionReceived,
            hasSelectionItem: true,
            guardPassed: true,
            beganPendingProcessing: beganPendingProcessing,
            pendingImageStatus: model.inputState.pendingImage?.status
        )
        #endif

        switch await photoLibraryImageLoader(item) {
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
