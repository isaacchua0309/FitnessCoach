//
//  CoachPhotoPickerTransfer.swift
//  Fitness Coach
//
//  Forma — PhotosPicker transferable wrapper for raw image bytes.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct CoachPhotoPickerTransfer: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { received in
            CoachPhotoPickerTransfer(data: received)
        }
        DataRepresentation(importedContentType: .jpeg) { received in
            CoachPhotoPickerTransfer(data: received)
        }
    }
}
