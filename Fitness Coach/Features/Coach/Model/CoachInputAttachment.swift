//
//  CoachInputAttachment.swift
//  Fitness Coach
//
//  Forma — Single optional image attachment for the Coach composer.
//

import Foundation
import UIKit

/// Normalized JPEG payload staged for the next Coach send.
struct CoachInputAttachment: Equatable, Identifiable, Sendable {
    let id: UUID
    let jpegData: Data
    let sourceLabel: String?

    var previewImage: UIImage? {
        UIImage(data: jpegData)
    }
}

enum CoachAttachmentImportPhase: Equatable, Sendable {
    case idle
    case importing
    case failed(CoachMealPhotoError)
}

/// Exactly one optional attachment slot for the Coach input bar.
struct CoachInputAttachmentState: Equatable, Sendable {
    var attachment: CoachInputAttachment?
    var importPhase: CoachAttachmentImportPhase = .idle

    static let none = CoachInputAttachmentState()

    var hasAttachment: Bool {
        attachment != nil
    }

    var isImporting: Bool {
        importPhase == .importing
    }

    var importError: CoachMealPhotoError? {
        if case .failed(let error) = importPhase {
            return error
        }
        return nil
    }

    var previewImage: UIImage? {
        attachment?.previewImage
    }

    mutating func clear() {
        self = .none
    }

    mutating func beginImport() {
        importPhase = .importing
    }

    mutating func cancelImport() {
        importPhase = .idle
    }

    mutating func applyImported(jpegData: Data, sourceLabel: String?) {
        attachment = CoachInputAttachment(
            id: UUID(),
            jpegData: jpegData,
            sourceLabel: sourceLabel
        )
        importPhase = .idle
    }

    mutating func failImport(_ error: CoachMealPhotoError) {
        importPhase = .failed(error)
    }

    mutating func dismissImportError() {
        guard importError != nil else { return }
        importPhase = .idle
    }
}
