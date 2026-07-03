//
//  SettingsDeleteDataPresentationModels.swift
//  Fitness Coach
//
//  Forma — Delete data confirmation presentation models.
//

import Foundation

struct SettingsDeleteDataPresentation: Equatable, Sendable {
    let confirmationTitle: String
    let confirmationMessage: String
    let confirmActionTitle: String
    let unavailableTitle: String
    let unavailableMessage: String
}

enum SettingsDeleteDataResult: Equatable, Sendable {
    case completed
    case notImplemented
}
