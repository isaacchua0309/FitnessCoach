//
//  PlanEditComponentModels.swift
//  Fitness Coach
//
//  Forma — Display models for reusable Edit Plan UI components.
//

import Foundation

struct PlanMetricRowDisplayModel: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let value: String

    init(id: String = UUID().uuidString, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

struct PlanMacroSummaryCardDisplayModel: Equatable, Sendable {
    let title: String?
    let rows: [PlanMetricRowDisplayModel]
    let footerText: String?
    let compact: Bool

    init(
        title: String? = nil,
        rows: [PlanMetricRowDisplayModel],
        footerText: String? = nil,
        compact: Bool = false
    ) {
        self.title = title
        self.rows = rows
        self.footerText = footerText
        self.compact = compact
    }
}

struct PlanTimelinePreviewDisplayModel: Equatable, Sendable {
    let currentWeight: String
    let targetWeight: String
    let progressFraction: Double
}

struct PlanDifficultyBadgeDisplayModel: Equatable, Sendable {
    let label: String
    let description: String?
}

struct PlanWarningCardDisplayModel: Equatable, Sendable {
    let title: String
    let body: String
}

struct PlanSuccessCardDisplayModel: Equatable, Sendable {
    enum Variant: Equatable, Sendable {
        case statusBanner(isUpToDate: Bool)
    }

    let headline: String
    let variant: Variant
}

struct PlanSegmentedOption: Identifiable, Equatable, Sendable {
    let id: String
    let title: String

    init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

struct PlanInputFieldDisplayModel: Equatable, Sendable {
    enum ValueStyle: Equatable, Sendable {
        case title
        case largeTitle
    }

    let title: String
    let placeholder: String
    let unitLabel: String?
    let validationMessage: String?
    let isFocused: Bool
    let valueStyle: ValueStyle
    let usesCompactChrome: Bool

    init(
        title: String,
        placeholder: String,
        unitLabel: String? = nil,
        validationMessage: String? = nil,
        isFocused: Bool = false,
        valueStyle: ValueStyle = .title,
        usesCompactChrome: Bool = false
    ) {
        self.title = title
        self.placeholder = placeholder
        self.unitLabel = unitLabel
        self.validationMessage = validationMessage
        self.isFocused = isFocused
        self.valueStyle = valueStyle
        self.usesCompactChrome = usesCompactChrome
    }
}
