//
//  CompeteViewModel.swift
//  klymb
//
//  ViewModel for Leaderboards & Competitions (PRD §F10 & AGENTS.md Rules 2, 15, 16).
//  All KP balances and ranks are server-authoritative; no client calculation.
//

import SwiftUI
import Combine

@MainActor
public final class CompeteViewModel: ObservableObject {
    @Published public var selectedScope: LeaderboardScope = .city
    @Published public var selectedPeriod: LeaderboardPeriod = .daily
    @Published public var entries: [LeaderboardEntry] = []
    @Published public var myEntry: LeaderboardEntry? = nil
    @Published public var selectedAthlete: LeaderboardEntry? = nil
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil

    private let leaderboardService: LeaderboardServiceProtocol
    private let profileService: ProfileServiceProtocol

    public init(container: AppContainerProtocol = AppContainer.mock) {
        self.leaderboardService = container.leaderboardService
        self.profileService = container.profileService
    }

    public init(
        leaderboardService: LeaderboardServiceProtocol,
        profileService: ProfileServiceProtocol
    ) {
        self.leaderboardService = leaderboardService
        self.profileService = profileService
    }

    // MARK: - Computed Properties

    public var topThree: [LeaderboardEntry] {
        Array(entries.prefix(3))
    }

    public var remainingEntries: [LeaderboardEntry] {
        guard entries.count > 3 else { return [] }
        return Array(entries.dropFirst(3))
    }

    public var overtakeNudgeText: String? {
        guard let my = myEntry else { return nil }
        if my.rank == 1 {
            return "👑 You are leading the pack!"
        }
        // Find person right above me
        if let target = entries.first(where: { $0.rank == my.rank - 1 }) {
            let diff = max(1, target.totalKP - my.totalKP + 1)
            let targetName = target.displayName ?? "@\(target.username)"
            return "⚡️ \(diff) KP to overtake #\(target.rank) \(targetName)"
        }
        return nil
    }

    // MARK: - Actions

    public func fetchLeaderboard() async {
        isLoading = true
        errorMessage = nil

        do {
            async let fetchedEntries = leaderboardService.getLeaderboard(
                period: selectedPeriod.rawValue,
                scope: selectedScope.rawValue,
                limit: 50,
                offset: 0
            )
            async let fetchedMyRank = leaderboardService.getMyRank(
                period: selectedPeriod.rawValue,
                scope: selectedScope.rawValue
            )

            let (entriesResult, myRankResult) = try await (fetchedEntries, fetchedMyRank)
            self.entries = entriesResult
            self.myEntry = myRankResult ?? entriesResult.first(where: { $0.isCurrentUser })
            self.isLoading = false
        } catch {
            self.errorMessage = "Unable to load leaderboard. Pull down to retry."
            self.isLoading = false
        }
    }

    public func setScope(_ scope: LeaderboardScope) {
        guard scope != selectedScope else { return }
        selectedScope = scope
        HapticManager.selection()
        Task {
            await fetchLeaderboard()
        }
    }

    public func setPeriod(_ period: LeaderboardPeriod) {
        guard period != selectedPeriod else { return }
        selectedPeriod = period
        HapticManager.selection()
        Task {
            await fetchLeaderboard()
        }
    }

    public func selectAthlete(_ entry: LeaderboardEntry) {
        selectedAthlete = entry
        HapticManager.selection()
    }

    public func dismissAthleteProfile() {
        selectedAthlete = nil
    }
}
