//
//  CoachContextDebugEnvironment.swift
//  Fitness Coach
//
//  Forma — DEBUG-only environment hook for Coach context inspection.
//

#if DEBUG
import SwiftUI

private struct CoachContextDebugActionsKey: EnvironmentKey {
    static let defaultValue: CoachContextDebugActions? = nil
}

extension EnvironmentValues {
    var coachContextDebugActions: CoachContextDebugActions? {
        get { self[CoachContextDebugActionsKey.self] }
        set { self[CoachContextDebugActionsKey.self] = newValue }
    }
}
#endif
