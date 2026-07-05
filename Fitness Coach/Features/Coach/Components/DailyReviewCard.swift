//
//  DailyReviewCard.swift
//  Fitness Coach
//
//  Forma — Coach chat wrapper for `DailyReviewCardView`.
//

import SwiftUI

struct DailyReviewCard: View {
    let payload: DailyReviewPayload

    var body: some View {
        DailyReviewCardView(payload: payload)
    }
}
