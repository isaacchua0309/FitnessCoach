//
//  DiscardChangesConfirmationRenderTestSupport.swift
//  Fitness CoachTests
//
//  Forma — Rendering helpers for discard confirmation UI tests.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

@MainActor
enum DiscardChangesConfirmationRenderTestSupport {

    static func confirmationView(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        ZStack {
            FormaTokens.Color.canvas
                .ignoresSafeArea()

            DiscardChangesConfirmationView(
                title: FormaProductCopy.PlanEditWizardCopy.discardChangesTitle,
                message: FormaProductCopy.PlanEditWizardCopy.discardChangesMessage,
                keepEditingTitle: FormaProductCopy.PlanEditWizardCopy.keepEditing,
                discardTitle: FormaProductCopy.PlanEditWizardCopy.discardChanges,
                onKeepEditing: {},
                onDiscard: {}
            )
        }
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    @discardableResult
    static func assertRenders(
        size: CGSize,
        dynamicTypeSize: DynamicTypeSize = .large,
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> UIImage? {
        AdjustPlanRenderTestSupport.assertRenders(
            confirmationView(palette: palette, appearance: appearance),
            size: size,
            dynamicTypeSize: dynamicTypeSize,
            file: file,
            line: line
        )
    }
}
