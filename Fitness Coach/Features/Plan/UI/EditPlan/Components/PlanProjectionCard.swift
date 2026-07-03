//
//  PlanProjectionCard.swift
//  Fitness Coach
//
//  Forma — Themed projection card shell for Edit Plan.
//

import SwiftUI

struct PlanProjectionCard<Content: View>: View {
    var compact: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        PlanEditCard(compact: compact) {
            content()
        }
    }
}
