//
//  DebugRecordEntity+Mapping.swift
//  Fitness Coach
//
//  Mapping for dormant `DebugRecordEntity`. See `Docs/PersistenceCleanupNotes.md`.
//
//  The domain context dictionary is encoded to/from a JSON string so SwiftData
//  only needs to persist a plain String when persistence is re-enabled.
//

import Foundation

extension DebugRecordEntity {

    convenience init(model: DebugRecord) {
        self.init(
            id: model.id,
            categoryRawValue: model.category.rawValue,
            message: model.message,
            contextJson: DebugRecordEntity.encodeContext(model.context),
            createdAt: model.createdAt
        )
    }

    func toModel() -> DebugRecord {
        DebugRecord(
            id: id,
            category: DebugCategory(rawValue: categoryRawValue) ?? .persistenceFailure,
            message: message,
            context: DebugRecordEntity.decodeContext(contextJson),
            createdAt: createdAt
        )
    }

    // MARK: Context Encoding

    static func encodeContext(_ context: [String: String]) -> String {
        guard
            let data = try? JSONEncoder().encode(context),
            let json = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return json
    }

    static func decodeContext(_ json: String) -> [String: String] {
        guard
            let data = json.data(using: .utf8),
            let context = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return context
    }
}
