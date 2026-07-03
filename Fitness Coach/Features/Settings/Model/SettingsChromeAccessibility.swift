//
//  SettingsChromeAccessibility.swift
//  Fitness Coach
//
//  Forma — Layout and accessibility contract for Settings screens.
//

import CoreGraphics

enum SettingsChromeAccessibility {

    /// Extra space above grouped list section titles.
    static let sectionHeaderTopPadding: CGFloat = 4

    /// Space below section titles before the first row.
    static let sectionHeaderBottomPadding: CGFloat = 2

    /// Vertical rhythm between blocks on pushed settings detail screens.
    static let detailSectionSpacing: CGFloat = 16

    /// Top inset for detail scroll content (below inline navigation bar).
    static let detailPageTopPadding: CGFloat = 12

    /// Bottom inset before safe-area scroll padding.
    static let detailPageBottomPadding: CGFloat = 8

    /// Maximum lines for hub row titles at large Dynamic Type sizes.
    static let rowTitleLineLimit: Int = 2

    /// Maximum lines for trailing status labels.
    static let statusLineLimit: Int = 2

    /// Minimum row height for tappable settings rows.
    static let minimumRowTouchTarget: CGFloat = 44

    /// Minimum height for full-width settings action buttons.
    static let minimumActionButtonHeight: CGFloat = 44

    /// Label column width for compact account/connection rows.
    static let detailLabelColumnWidth: CGFloat = 76

    /// Slightly wider label column for Apple Health connection rows.
    static let connectionLabelColumnWidth: CGFloat = 88
}

enum SettingsRowAccessibilityPolicy {

    /// Button-backed rows (mailto, external legal links) show a trailing affordance.
    static let includesDisclosureForButtonRows = true

    /// NavigationLink rows rely on the system chevron in grouped lists.
    static let usesSystemNavigationChevron = true

    /// Enabled destructive actions use full semantic destructive color.
    static let destructiveUsesFullContrastWhenEnabled = true

    /// Row titles and status labels may wrap for Dynamic Type.
    static let supportsDynamicTypeWrapping = true

    /// Account email fields wrap across lines instead of truncating.
    static let supportsLongEmailWrapping = true
}

enum SettingsRowAccessibilityFormatter {

    static func label(title: String, status: String?) -> String {
        guard let status, !status.isEmpty else { return title }
        return "\(title), \(status)"
    }

    static func buttonHint(opensExternally: Bool) -> String {
        opensExternally ? "Opens in browser" : "Opens details"
    }
}
