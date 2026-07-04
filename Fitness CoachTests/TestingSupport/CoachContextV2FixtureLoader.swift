//
//  CoachContextV2FixtureLoader.swift
//  Fitness CoachTests
//
//  Loads mirrored backend CoachContextPacketV2 JSON contract fixtures.
//

import Foundation
@testable import Fitness_Coach

enum CoachContextV2FixtureLoader {

    static let fixturesDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/CoachContextV2", isDirectory: true)

    static func data(named name: String) throws -> Data {
        let url = fixturesDirectory.appendingPathComponent("\(name).json")
        return try Data(contentsOf: url)
    }

    static func decodeContext(named name: String) throws -> CoachContextPacketV2 {
        try CoachContextPacketV2.makeJSONDecoder().decode(
            CoachContextPacketV2.self,
            from: data(named: name)
        )
    }

    static func decodeJSONObject(named name: String) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: data(named: name))
        guard let dictionary = object as? [String: Any] else {
            throw NSError(domain: "CoachContextV2FixtureLoader", code: 1)
        }
        return dictionary
    }

    static func schemaVersion(in data: Data) throws -> Int {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let meta = root?["meta"] as? [String: Any]
        return meta?["schemaVersion"] as? Int ?? -1
    }
}
