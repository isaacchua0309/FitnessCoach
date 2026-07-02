//
//  CoachAttachmentImportCoordinator.swift
//  Fitness Coach
//
//  Forma — Guards staged attachment imports against stale async completion.
//

import Foundation

struct CoachAttachmentImportCoordinator: Equatable, Sendable {
    private(set) var generation: UInt = 0

    mutating func beginImport() -> UInt {
        generation &+= 1
        return generation
    }

    mutating func invalidate() {
        generation &+= 1
    }

    func isCurrent(_ token: UInt) -> Bool {
        token == generation
    }
}
