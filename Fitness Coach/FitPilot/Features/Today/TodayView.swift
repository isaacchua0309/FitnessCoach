//
//  TodayView.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only daily status. Answers: "Am I on track today?"
//
//  All logging and updates route to Coach via onOpenCoach.
//

import SwiftUI

struct TodayView: View {

    @ObservedObject var model: TodayModel
    @EnvironmentObject private var refreshCenter: AppRefreshCenter

    /// Optional prefill text for Coach input. `nil` opens Coach without prefilling.
    var onOpenCoach: ((String?) -> Void)?

    init(model: TodayModel, onOpenCoach: ((String?) -> Void)? = nil) {
        self.model = model
        self.onOpenCoach = onOpenCoach
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Today")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await model.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                .task {
                    await model.loadToday()
                }
                .onChange(of: refreshCenter.refreshToken) { _, _ in
                    Task<Void, Never> {
                        await model.refresh()
                    }
                }
                .onAppear {
                    if case .loaded = model.viewState {
                        Task<Void, Never> {
                            await model.refresh()
                        }
                    }
                }
                .refreshable {
                    await model.refresh()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.viewState {
        case .loading:
            TodayLoadingView()
        case .empty:
            TodayEmptyStateView {
                Task { await model.refresh() }
            }
        case .error(let message):
            TodayErrorView(message: message) {
                Task { await model.refresh() }
            }
        case .loaded(let state):
            dashboard(state)
        }
    }

    private func dashboard(_ state: TodayDashboardState) -> some View {
        ScrollView {
            TodayReadOnlyView(state: state) { prefill in
                onOpenCoach?(prefill)
            }
            .padding(.horizontal, TodayLayout.horizontalPadding)
            .padding(.vertical, 16)
        }
    }
}

#Preview {
    let container = try! AppContainer(inMemory: true)
    TodayView(model: container.makeTodayModel())
        .environmentObject(container.refreshCenter)
}
