//
//  CoachInputCoordinator.swift
//  Fitness Coach
//
//  Forma — Composer text draft, attachment staging, and send snapshot coordination.
//

import Foundation
import UIKit

@MainActor
final class CoachInputCoordinator {

    private(set) var state: CoachInputState = .empty

    var onStateChange: ((CoachInputState) -> Void)?

    private let pendingImageLocalSources = CoachPendingImageLocalSourceStore()
    private var isSendingProvider: () -> Bool

    init(isSendingProvider: @escaping () -> Bool = { false }) {
        self.isSendingProvider = isSendingProvider
    }

    func configureSendingState(_ provider: @escaping () -> Bool) {
        isSendingProvider = provider
    }

    var inputText: String {
        get { state.text }
        set { mutateState { $0.updateText(newValue) } }
    }

    // MARK: Text draft

    func setText(_ text: String) {
        mutateState { $0.updateText(text) }
    }

    func clearText() {
        mutateState { $0.updateText("") }
    }

    func clearComposerContent() {
        mutateState { state in
            state.updateText("")
            state.clearPendingImage()
            state.clearImageError()
        }
    }

    // MARK: Meal photo attachment

    func removeStagedMealPhoto() {
        let localReferenceID = state.pendingImage?.localReferenceID
        mutateState { $0.clearPendingImage() }
        pendingImageLocalSources.remove(localReferenceID)
    }

    func storePendingImageLocalSource(_ image: UIImage) -> UUID {
        pendingImageLocalSources.store(image)
    }

    func pendingImageLocalSource(for id: UUID) -> UIImage? {
        pendingImageLocalSources.image(for: id)
    }

    func attachPendingImageLocalReference(_ id: UUID) {
        mutateState { state in
            guard var pending = state.pendingImage else { return }
            pending.localReferenceID = id
            state.pendingImage = pending
        }
    }

    func clearPendingImageError() {
        mutateState { $0.clearImageError() }
    }

    @discardableResult
    func beginPendingImageProcessing(source: CoachInputAttachmentSource) -> Bool {
        guard state.canStartImageSelection else { return false }
        mutateState { $0.beginProcessingNewSelection(source: source) }
        return true
    }

    func hasActivePendingImageImport() -> Bool {
        state.pendingImage?.isProcessing == true
    }

    func shouldAcceptImportSuccess(localReferenceID: UUID) -> Bool {
        guard let pending = state.pendingImage, pending.isProcessing else { return false }
        return pending.localReferenceID == localReferenceID
    }

    @discardableResult
    func requestPhotoPick() -> Bool {
        state.canStartImageSelection
    }

    @discardableResult
    func stagePipelineProcessedPhoto(
        _ imported: CoachImagePipeline.ProcessedImageImport,
        source: CoachInputAttachmentSource
    ) async -> Bool {
        let processed = imported.processed

        let staged = mutateState { state -> Bool in
            if let pending = state.pendingImage, pending.isProcessing {
                guard pending.localReferenceID == imported.localReferenceID else {
                    return false
                }
            }
            state.applyProcessedImage(
                processed,
                source: source,
                originalEstimatedBytes: imported.originalEstimatedBytes,
                localReferenceID: imported.localReferenceID
            )
            return true
        }

        guard staged else { return false }

        CoachMealPhotoPipeline.assertImagePayloadPresent(processed.uploadData)
        return true
    }

    func failPendingImageProcessing(_ error: CoachMealPhotoError) {
        guard hasActivePendingImageImport() else { return }
        mutateState { $0.failImageProcessing(error) }
    }

    func revertPendingImageProcessingCancel() {
        mutateState { state in
            guard var pending = state.pendingImage, pending.isProcessing else { return }
            if pending.byteSize == 0 {
                state.clearPendingImage()
            } else {
                pending.markFailedPreservingReadyPayload()
                state.pendingImage = pending
            }
        }
    }

    // MARK: Send snapshot

    /// Clears any staged meal photo before a text-only outbound command (e.g. daily review starter).
    func discardStagedAttachmentForTextSend() {
        guard state.pendingImage != nil || state.imageError != nil else { return }
        mutateState { state in
            state.clearPendingImage()
        }
    }

    /// Freezes the current composer payload, clears editable fields, and returns the snapshot.
    func takeSendSnapshot() -> CoachInputSendSnapshot? {
        var next = state
        guard let snapshot = next.takeSendSnapshot() else { return nil }
        commitState(next)
        return snapshot
    }

    /// Restores composer fields after an outbound send aborts before a user message is created.
    func restoreComposer(from snapshot: CoachInputSendSnapshot) {
        mutateState { $0.restore(from: snapshot) }
    }

    func syncSendingFlag() {
        commitState(
            CoachModelStateReducer.inputState(state, syncedToSending: isSendingProvider())
        )
    }

    // MARK: State mutation

    @discardableResult
    private func mutateState<T>(_ transform: (inout CoachInputState) -> T) -> T {
        var next = state
        let value = transform(&next)
        commitState(next)
        return value
    }

    private func commitState(_ next: CoachInputState) {
        let committed = CoachModelStateReducer.inputState(
            next,
            syncedToSending: isSendingProvider()
        )
        state = committed
        onStateChange?(committed)
    }
}
