//
//  CoachAttachmentMenu.swift
//  Fitness Coach
//
//  Forma — Photo picker destination for Coach composer attachments.
//

import Foundation

enum CoachPhotoPickerDestination: Equatable, Sendable {
    case none
    case camera
    case photoLibrary

    var isPresentingPicker: Bool {
        self != .none
    }
}
