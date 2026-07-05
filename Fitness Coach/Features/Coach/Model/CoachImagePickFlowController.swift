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

    /// Generation token for the active photo-library picker session.
    private var activeLibraryPickID: UUID?
    /// Selection received for `activeLibraryPickID` and not yet finished processing.
    private var librarySelectionInFlightID: UUID?
    /// After dismiss, accept a late callback only when it matches this pick generation.
    private var awaitingLateSelectionPickID: UUID?

    private let photoLibraryImageLoader: CoachPhotoLibraryImageLoader

    #if DEBUG
    /// Test-only hook invoked before claiming a library selection for processing.
    var debugPhotoLibrarySelectionEntryHook: (@MainActor () async -> Void)?
    #endif

    init(
        photoLibraryImageLoader: @escaping CoachPhotoLibraryImageLoader = CoachPhotoLibraryImageLoading.live
    ) {
        self.photoLibraryImageLoader = photoLibraryImageLoader
    }

    var allowsAttachmentPick: Bool {
        !state.isBusy
    }

    var isProcessingImage: Bool {
        state.isProcessingImage
    }

    /// Active photo-library pick generation token; nil when no library pick is open.
    var activeLibraryPickSessionID: UUID? {
        activeLibraryPickID
    }

    func handleAttachmentRemoved() {
        clearLibraryPickSession()
        isPhotoPickerPresented = false
        isCameraPresented = false
        state = .idle
    }

    func markLibrarySelectionReceived(claimedPickID: UUID) {
        guard claimedPickID == activeLibraryPickID else {
            logStaleLibrarySelection(reason: "claimed_pick_mismatch")
            return
        }

        guard let pickID = activeLibraryPickID else {
            logStaleLibrarySelection(reason: "no_active_pick")
            return
        }

        guard canAcceptLibrarySelection(for: pickID) else {
            logStaleLibrarySelection(reason: "stale_pick_generation")
            return
        }

        librarySelectionInFlightID = pickID
        #if DEBUG
        CoachPhotoLibraryPickDebugLogger.log(
            .librarySelectionReceived,
            flowState: state,
            isPhotoPickerPresented: isPhotoPickerPresented,
            librarySelectionReceived: true,
            extra: libraryPickDebugFields()
        )
        #endif
    }

    #if DEBUG
    func debugLibrarySelectionReceivedForLogging() -> Bool {
        librarySelectionInFlightID != nil
    }
    #endif

    /// Synchronously claims a received library selection before async loading.
    @discardableResult
    func beginPhotoLibrarySelectionHandling() -> Bool {
        guard let pickID = librarySelectionInFlightID, pickID == activeLibraryPickID else {
            logStaleLibrarySelection(reason: "missing_or_mismatched_in_flight_pick")
            return false
        }

        if case .processingImage(.library) = state {
            return true
        }

        guard state == .pickerPresented(.library) || state == .idle else {
            logStaleLibrarySelection(reason: "invalid_state_for_claim")
            return false
        }

        awaitingLateSelectionPickID = nil
        isPhotoPickerPresented = false
        state = .processingImage(.library)

        #if DEBUG
        CoachPhotoLibraryPickDebugLogger.log(
            .librarySelectionAccepted,
            flowState: state,
            isPhotoPickerPresented: isPhotoPickerPresented,
            librarySelectionReceived: true,
            guardPassed: true,
            extra: libraryPickDebugFields()
        )
        #endif
        return true
    }

    func handleDroppedLibrarySelection(model: CoachModel) {
        #if DEBUG
        CoachPhotoLibraryPickDebugLogger.log(
            .librarySelectionDroppedUnexpectedState,
            flowState: state,
            isPhotoPickerPresented: isPhotoPickerPresented,
            librarySelectionReceived: librarySelectionInFlightID != nil,
            hasSelectionItem: true,
            guardPassed: false,
            extra: libraryPickDebugFields(reason: "unexpected_state_drop")
        )
        #endif
        resetLibraryPickFlowAfterFailure()
        model.reportComposerImageSelectionError(.attachFailed)
    }

    @discardableResult
    func beginPhotoLibraryPick(model: CoachModel) -> CoachPhotoLibraryPickBeginOutcome {
        if state != .idle {
            recoverInconsistentFlowStateIfNeeded()
        }

        guard state == .idle else {
            return .rejectedFlowBusy
        }

        if model.inputState.isSending {
            return .rejectedComposerSending
        }

        if model.inputState.isImageProcessing {
            return .rejectedComposerImageProcessing
        }

        guard model.requestPhotoPick() else {
            return .rejectedComposerSending
        }

        clearLibraryPickSession()
        activeLibraryPickID = UUID()
        state = .pickerPresented(.library)
        isPhotoPickerPresented = true
        #if DEBUG
        CoachPhotoLibraryPickDebugLogger.log(
            .libraryPickStarted,
            flowState: state,
            isPhotoPickerPresented: isPhotoPickerPresented,
            librarySelectionReceived: false,
            guardPassed: true,
            extra: libraryPickDebugFields()
        )
        #endif
        return .started
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
        if case .processingImage(.library) = state {
            return
        }

        if librarySelectionInFlightID != nil {
            return
        }

        guard case .pickerPresented(.library) = state else { return }

        awaitingLateSelectionPickID = activeLibraryPickID
        state = .idle
        isPhotoPickerPresented = false
        #if DEBUG
        CoachPhotoLibraryPickDebugLogger.log(
            .libraryPickCancelled,
            flowState: state,
            isPhotoPickerPresented: isPhotoPickerPresented,
            librarySelectionReceived: false,
            extra: libraryPickDebugFields()
        )
        #endif
    }

    func handlePhotoLibrarySelection(
        _ item: PhotosPickerItem,
        model: CoachModel
    ) async {
        #if DEBUG
        if let debugPhotoLibrarySelectionEntryHook {
            await debugPhotoLibrarySelectionEntryHook()
        }
        #endif

        let hadAcceptedSelection = librarySelectionInFlightID != nil
        guard beginPhotoLibrarySelectionHandling() else {
            if hadAcceptedSelection {
                handleDroppedLibrarySelection(model: model)
            }
            return
        }

        guard model.beginPendingImageProcessing(source: .library) else {
            #if DEBUG
            CoachPhotoLibraryPickDebugLogger.log(
                .libraryProcessingFailed,
                flowState: state,
                isPhotoPickerPresented: isPhotoPickerPresented,
                librarySelectionReceived: librarySelectionInFlightID != nil,
                hasSelectionItem: true,
                guardPassed: false,
                beganPendingProcessing: false,
                extra: libraryPickDebugFields(reason: "begin_pending_rejected")
            )
            #endif
            resetLibraryPickFlowAfterFailure()
            model.reportComposerImageSelectionError(.attachFailed)
            return
        }

        #if DEBUG
        CoachPhotoLibraryPickDebugLogger.log(
            .libraryProcessingStarted,
            flowState: state,
            isPhotoPickerPresented: isPhotoPickerPresented,
            librarySelectionReceived: librarySelectionInFlightID != nil,
            hasSelectionItem: true,
            guardPassed: true,
            beganPendingProcessing: true,
            pendingImageStatus: model.inputState.pendingImage?.status,
            extra: libraryPickDebugFields()
        )
        #endif

        defer {
            clearLibraryPickSession()
        }

        switch await photoLibraryImageLoader(item) {
        case .failure(let error):
            CoachImageProcessingLogger.logSelectionFailure(source: .library, originalSize: nil, error: error)
            #if DEBUG
            CoachPhotoLibraryPickDebugLogger.log(
                .libraryProcessingFailed,
                flowState: state,
                isPhotoPickerPresented: isPhotoPickerPresented,
                librarySelectionReceived: false,
                hasSelectionItem: true,
                extra: libraryPickDebugFields(reason: "load_failed")
            )
            #endif
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
            guard model.beginPendingImageProcessing(source: .camera) else {
                state = .idle
                return
            }
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

    // MARK: - Library pick session

    private func canAcceptLibrarySelection(for pickID: UUID) -> Bool {
        guard activeLibraryPickID == pickID else { return false }
        if case .pickerPresented(.library) = state { return true }
        return awaitingLateSelectionPickID == pickID
    }

    private func clearLibraryPickSession() {
        activeLibraryPickID = nil
        librarySelectionInFlightID = nil
        awaitingLateSelectionPickID = nil
    }

    private func resetLibraryPickFlowAfterFailure() {
        state = .idle
        isPhotoPickerPresented = false
        clearLibraryPickSession()
    }

    private func recoverInconsistentFlowStateIfNeeded() {
        switch state {
        case .imageReady, .failed:
            resetLibraryPickFlowAfterFailure()
        default:
            break
        }
    }

    private func logStaleLibrarySelection(reason: String) {
        _ = reason
    }

    #if DEBUG
    private func libraryPickDebugFields(reason: String? = nil) -> [String: String] {
        var fields: [String: String] = [:]
        if let activeLibraryPickID {
            fields["active_library_pick_id"] = activeLibraryPickID.uuidString
        }
        if let librarySelectionInFlightID {
            fields["library_selection_in_flight_id"] = librarySelectionInFlightID.uuidString
        }
        if let awaitingLateSelectionPickID {
            fields["awaiting_late_selection_pick_id"] = awaitingLateSelectionPickID.uuidString
        }
        if let reason {
            fields["reason"] = reason
        }
        return fields
    }
    #else
    private func libraryPickDebugFields(reason: String? = nil) -> [String: String] { [:] }
    #endif

    /// Dismisses any camera/photo-library UI when Coach is no longer the active tab.
    func dismissPresentedPickers() {
        cameraDeliveredResult = false
        isPhotoPickerPresented = false
        isCameraPresented = false
        switch state {
        case .pickerPresented:
            clearLibraryPickSession()
            state = .idle
        case .idle:
            clearLibraryPickSession()
        case .processingImage, .imageReady, .failed:
            break
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
                #if DEBUG
                let discardReason: String
                if model.inputState.pendingImage == nil {
                    discardReason = "user_removed"
                } else if model.inputState.pendingImage?.localReferenceID != localReferenceID {
                    discardReason = "reference_mismatch"
                } else {
                    discardReason = "no_active_import"
                }
                CoachPhotoLibraryPickDebugLogger.log(
                    .libraryProcessingDiscardedStale,
                    flowState: state,
                    isPhotoPickerPresented: isPhotoPickerPresented,
                    pendingImageStatus: model.inputState.pendingImage?.status,
                    extra: libraryPickDebugFields(reason: discardReason)
                )
                #endif
                state = .idle
                return
            }
            let staged = await model.stagePipelineProcessedPhoto(imported, source: source)
            if staged {
                #if DEBUG
                if source == .library {
                    CoachPhotoLibraryPickDebugLogger.log(
                        .libraryProcessingSucceeded,
                        flowState: state,
                        isPhotoPickerPresented: isPhotoPickerPresented,
                        pendingImageStatus: model.inputState.pendingImage?.status,
                        extra: libraryPickDebugFields()
                    )
                }
                #endif
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
