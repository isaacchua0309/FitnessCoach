//
//  CoachPhotoLibraryPickDebugLogger.swift
//  Fitness Coach
//
//  Temporary DEBUG instrumentation for Coach photo library pick flow.
//  Never logs image bytes, filenames, metadata, user text, or personal data.
//

import Foundation
import OSLog

#if DEBUG

enum CoachPhotoLibraryPickDebugEvent: String {
    case libraryPickStarted
    case libraryPickCancelled
    case librarySelectionReceived
    case librarySelectionAccepted
    case librarySelectionDroppedUnexpectedState
    case libraryProcessingStarted
    case libraryProcessingSucceeded
    case libraryProcessingFailed
    case libraryProcessingDiscardedStale
}

enum CoachPhotoLibraryPickDebugLogger {

    private static let logger = Logger(subsystem: "Forma", category: "CoachPhotoLibraryPick")

    /// Disable with `FORMA_COACH_PHOTO_LIBRARY_PICK_DEBUG=0`.
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["FORMA_COACH_PHOTO_LIBRARY_PICK_DEBUG"] != "0"
    }

    static func log(
        _ event: CoachPhotoLibraryPickDebugEvent,
        flowState: CoachImagePickFlowState? = nil,
        isPhotoPickerPresented: Bool? = nil,
        librarySelectionReceived: Bool? = nil,
        hasSelectionItem: Bool? = nil,
        guardPassed: Bool? = nil,
        beganPendingProcessing: Bool? = nil,
        pendingImageStatus: CoachPendingImageStatus? = nil,
        extra: [String: String] = [:]
    ) {
        guard isEnabled else { return }

        var fields: [String: String] = ["event": event.rawValue]
        if let flowState {
            fields["flow_state"] = flowState.debugLabel
        }
        if let isPhotoPickerPresented {
            fields["is_photo_picker_presented"] = String(isPhotoPickerPresented)
        }
        if let librarySelectionReceived {
            fields["library_selection_received"] = String(librarySelectionReceived)
        }
        if let hasSelectionItem {
            fields["has_selection_item"] = String(hasSelectionItem)
        }
        if let guardPassed {
            fields["guard_passed"] = String(guardPassed)
        }
        if let beganPendingProcessing {
            fields["began_pending_processing"] = String(beganPendingProcessing)
        }
        if let pendingImageStatus {
            fields["pending_image_status"] = pendingImageStatus.debugLabel
        }
        for (key, value) in extra.sorted(by: { $0.key < $1.key }) {
            fields[key] = value
        }

        let summary = fields
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        logger.debug("\(summary, privacy: .public)")
    }

    /// Non-flow UI instrumentation (composer previews, etc.).
    static func logDiagnostic(
        label: String,
        flowState: CoachImagePickFlowState? = nil,
        isPhotoPickerPresented: Bool? = nil,
        librarySelectionReceived: Bool? = nil,
        hasSelectionItem: Bool? = nil,
        guardPassed: Bool? = nil,
        beganPendingProcessing: Bool? = nil,
        pendingImageStatus: CoachPendingImageStatus? = nil,
        extra: [String: String] = [:]
    ) {
        guard isEnabled else { return }

        var fields: [String: String] = ["event": label]
        if let flowState {
            fields["flow_state"] = flowState.debugLabel
        }
        if let isPhotoPickerPresented {
            fields["is_photo_picker_presented"] = String(isPhotoPickerPresented)
        }
        if let librarySelectionReceived {
            fields["library_selection_received"] = String(librarySelectionReceived)
        }
        if let hasSelectionItem {
            fields["has_selection_item"] = String(hasSelectionItem)
        }
        if let guardPassed {
            fields["guard_passed"] = String(guardPassed)
        }
        if let beganPendingProcessing {
            fields["began_pending_processing"] = String(beganPendingProcessing)
        }
        if let pendingImageStatus {
            fields["pending_image_status"] = pendingImageStatus.debugLabel
        }
        for (key, value) in extra.sorted(by: { $0.key < $1.key }) {
            fields[key] = value
        }

        let summary = fields
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")

        logger.debug("\(summary, privacy: .public)")
    }
}

extension CoachImagePickFlowState {
    var debugLabel: String {
        switch self {
        case .idle:
            return "idle"
        case .requestingPermission(let source):
            return "requesting_permission_\(source.debugLabel)"
        case .pickerPresented(let source):
            return "picker_presented_\(source.debugLabel)"
        case .processingImage(let source):
            return "processing_image_\(source.debugLabel)"
        case .imageReady:
            return "image_ready"
        case .failed(let error):
            return "failed_\(String(describing: error))"
        }
    }
}

extension CoachImagePickSource {
    var debugLabel: String {
        switch self {
        case .camera: return "camera"
        case .library: return "library"
        }
    }
}

extension CoachPendingImageStatus {
    var debugLabel: String {
        switch self {
        case .processing: return "processing"
        case .ready: return "ready"
        case .failed: return "failed"
        }
    }
}

#endif
