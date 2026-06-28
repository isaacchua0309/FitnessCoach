//
//  CloudProfilePresence.swift
//  Fitness Coach
//
//  Forma — Result of probing Firestore for an existing profile snapshot.
//

import Foundation

enum CloudProfilePresence: Equatable, Sendable {
    case absent
    case present(CloudUserProfileDocument)
}
