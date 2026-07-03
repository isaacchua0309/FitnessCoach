//
//  CoachPendingImageLocalSourceStore.swift
//  Fitness Coach
//
//  Retains original UIImages for in-composer meal-photo processing retry.
//

import UIKit

@MainActor
final class CoachPendingImageLocalSourceStore {

    private var images: [UUID: UIImage] = [:]

    func store(_ image: UIImage) -> UUID {
        let id = UUID()
        images[id] = image
        return id
    }

    func image(for id: UUID) -> UIImage? {
        images[id]
    }

    func remove(_ id: UUID?) {
        guard let id else { return }
        images.removeValue(forKey: id)
    }

    func removeAll() {
        images.removeAll()
    }
}
