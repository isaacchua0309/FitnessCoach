//
//  HealthSampleNormalizer.swift
//  Fitness Coach
//
//  Forma — Maps platform health payloads into `HealthNormalizedSample` values.
//

import Foundation

protocol HealthSampleNormalizing: Sendable {
    func normalize(samples: [HealthNormalizedSample]) -> [HealthNormalizedSample]
}

struct HealthSampleNormalizer: HealthSampleNormalizing {

    func normalize(samples: [HealthNormalizedSample]) -> [HealthNormalizedSample] {
        // TODO: Deduplicate overlapping sources, clamp invalid ranges, and merge intervals.
        samples.sorted { $0.startDate < $1.startDate }
    }
}
