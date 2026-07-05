//
//  TodayRecoverySectionFormatting.swift
//  Fitness Coach
//
//  Forma — Compact vs full recovery presentation on Today.
//

import Foundation

enum TodayRecoverySectionFormatting {

    static func isCompact(_ state: TodayRecoveryCardState) -> Bool {
        switch state.phase {
        case .unknown, .limitedEstimate:
            return true
        case .ready, .moderate, .low:
            return false
        }
    }

    static func compactTitle(for state: TodayRecoveryCardState) -> String {
        if state.title == FormaProductCopy.Today.Recovery.unclearTitle {
            return state.title
        }
        return FormaProductCopy.Today.Recovery.unclearTitle
    }

    static func compactBody(for state: TodayRecoveryCardState) -> String {
        if let subtitle = state.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !subtitle.isEmpty {
            return subtitle
        }
        return FormaProductCopy.Today.Recovery.unclearBody
    }

    static func compactAccessibilityLabel(for state: TodayRecoveryCardState) -> String {
        [
            FormaProductCopy.Today.Recovery.sectionTitle,
            compactTitle(for: state),
            compactBody(for: state)
        ].joined(separator: ". ")
    }
}
