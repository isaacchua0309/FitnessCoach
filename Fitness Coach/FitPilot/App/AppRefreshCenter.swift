//
//  AppRefreshCenter.swift
//  Fitness Coach
//
//  FitPilot AI — Lightweight cross-tab refresh signal.
//
//  Signals that shared data changed. It does not know what changed,
//  call services, or contain business logic.
//

import Combine
import Foundation

@MainActor
final class AppRefreshCenter: ObservableObject {

    @Published private(set) var refreshToken: Int = 0

    func notifyDataChanged() {
        refreshToken += 1
    }
}
