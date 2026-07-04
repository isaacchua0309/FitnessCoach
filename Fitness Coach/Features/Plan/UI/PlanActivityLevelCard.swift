//
//  PlanActivityLevelCard.swift
//  Fitness Coach
//
//  Forma — Selectable activity level card for Edit Plan.
//

import SwiftUI

struct PlanActivityLevelCard: View {
    let presentation: PlanActivityLevelPresentation
    let isSelected: Bool
    let action: () -> Void

    private let copy = FormaProductCopy.PlanEditActivity.self

    var body: some View {
        PlanSelectableCard(
            isSelected: isSelected,
            accessibilityLabel: accessibilityLabel,
            action: action
        ) {
            HStack(alignment: .top, spacing: FormaTokens.Spacing.md) {
                Image(systemName: presentation.iconSystemName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(
                        isSelected
                            ? FormaPlanTokens.Color.planAccent
                            : FormaPlanTokens.Color.planSecondaryText
                    )
                    .frame(width: 28, height: 28)
                    .padding(.top, 2)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                    headerRow

                    Text(presentation.description)
                        .font(FormaTokens.Typography.body)
                        .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(presentation.exampleBehavior)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let maintenanceImpactLabel = presentation.maintenanceImpactLabel {
                        Text(maintenanceImpactLabel)
                            .font(FormaTokens.Typography.caption.weight(.semibold))
                            .foregroundStyle(FormaPlanTokens.Color.planAccent)
                            .padding(.top, 2)
                    }
                }

                PlanSelectableCardAccessory.selectionCheckmark(isSelected: isSelected)
                    .padding(.top, 2)
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(presentation.title)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
            Spacer(minLength: 0)
        }
    }

    private var accessibilityLabel: String {
        var parts = [
            presentation.title,
            presentation.description,
            presentation.exampleBehavior
        ]
        if let maintenanceImpactLabel = presentation.maintenanceImpactLabel {
            parts.append("\(copy.maintenanceImpactLabel), \(maintenanceImpactLabel)")
        }
        return parts.joined(separator: ". ")
    }
}

#if DEBUG
#Preview("Activity Card") {
    let presentation = PlanActivityLevelPresentationBuilder.presentation(
        for: .moderatelyActive,
        formState: PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
    )

    return PlanActivityLevelCard(
        presentation: presentation,
        isSelected: true,
        action: {}
    )
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
