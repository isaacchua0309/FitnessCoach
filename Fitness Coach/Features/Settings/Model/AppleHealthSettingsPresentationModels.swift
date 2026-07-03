//
//  AppleHealthSettingsPresentationModels.swift
//  Fitness Coach
//
//  Forma — Presentation models for Settings → Apple Health.
//

import Foundation

enum AppleHealthSettingsPrimaryAction: Equatable, Sendable {
    case openHealthApp
    case connectAppleHealth
    case none
}

struct AppleHealthSettingsConnectionRow: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let value: String
}

struct AppleHealthSettingsPresentationInput: Equatable, Sendable {
    let integrationState: TrainingIntegrationState
    let lastSyncDate: Date?
}

struct AppleHealthSettingsPresentation: Equatable, Sendable {
    let screenTitle: String
    let heroStatus: String
    let heroShowsConnected: Bool
    let trustCopy: [String]
    let connectionCardTitle: String
    let connectionRows: [AppleHealthSettingsConnectionRow]
    let primaryAction: AppleHealthSettingsPrimaryAction
    let primaryActionTitle: String?
    let isPrimaryActionEnabled: Bool
    let primaryActionAccessibilityHint: String?
}
