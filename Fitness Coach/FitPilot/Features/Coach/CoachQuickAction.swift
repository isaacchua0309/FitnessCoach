//
//  CoachQuickAction.swift
//  Fitness Coach
//
//  FitPilot AI — Quick action chips for the Coach chat shell.
//
//  Each quick action maps to a predefined command string that is sent through
//  the same parsing path as typed input.
//

import Foundation

enum CoachQuickAction: String, CaseIterable, Identifiable, Sendable {
    case status
    case newDay
    case logWater
    case logWeight
    case dailyReview

    var id: String { rawValue }

    /// User-facing chip label.
    var label: String {
        switch self {
        case .status:
            return "Status"
        case .newDay:
            return "New Day"
        case .logWater:
            return "+500ml Water"
        case .logWeight:
            return "Log Weight"
        case .dailyReview:
            return "Daily Review"
        }
    }

    var systemImage: String {
        switch self {
        case .status:
            return "chart.bar"
        case .newDay:
            return "calendar.badge.plus"
        case .logWater:
            return "drop.fill"
        case .logWeight:
            return "scalemass"
        case .dailyReview:
            return "doc.text"
        }
    }

    /// A predefined command to send immediately, or nil if the action should
    /// instead prefill the input field (see `prefillText`).
    var commandText: String? {
        switch self {
        case .status:
            return "status"
        case .newDay:
            return "new day"
        case .logWater:
            return "+500ml"
        case .dailyReview:
            return "daily review"
        case .logWeight:
            return nil
        }
    }

    /// Text used to prefill the input field when the action requires more user
    /// input before it can be sent.
    var prefillText: String? {
        switch self {
        case .logWeight:
            return "weight "
        default:
            return nil
        }
    }
}
