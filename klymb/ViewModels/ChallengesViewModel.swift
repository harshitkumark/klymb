//
//  ChallengesViewModel.swift
//  klymb
//
//  ViewModel for Challenges & Goals (PRD §F12 & AGENTS.md Rules 2, 15, 16).
//  Daily, weekly, and community challenges.
//

import SwiftUI
import Combine

@MainActor
public final class ChallengesViewModel: ObservableObject {
    @Published public var selectedCategory: ChallengeCategoryFilter = .all
    @Published public var challenges: [Challenge] = []
    @Published public var selectedChallenge: Challenge? = nil
    @Published public var standings: [LeaderboardEntry] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var isActionLoading: Bool = false

    private let challengeService: ChallengeServiceProtocol

    public init(challengeService: ChallengeServiceProtocol) {
        self.challengeService = challengeService
    }

    public init(container: AppContainerProtocol = AppContainer.mock) {
        self.challengeService = container.challengeService
    }

    // MARK: - Computed Properties

    public var filteredChallenges: [Challenge] {
        switch selectedCategory {
        case .all:
            return challenges
        case .daily:
            return challenges.filter { $0.type == "daily" }
        case .weekly:
            return challenges.filter { $0.type == "weekly" }
        case .community:
            return challenges.filter { $0.type == "community" }
        }
    }

    public var joinedChallengesCount: Int {
        challenges.filter { $0.isJoined }.count
    }

    public var potentialRewardKP: Int {
        challenges.filter { $0.isJoined }.reduce(0) { $0 + $1.rewardKP }
    }

    // MARK: - Actions

    public func fetchChallenges() async {
        isLoading = true
        errorMessage = nil

        do {
            self.challenges = try await challengeService.getActiveChallenges()
            self.isLoading = false
        } catch {
            self.errorMessage = "Unable to load challenges. Pull down to retry."
            self.isLoading = false
        }
    }

    public func setCategory(_ category: ChallengeCategoryFilter) {
        guard category != selectedCategory else { return }
        selectedCategory = category
        HapticManager.selection()
    }

    public func selectChallenge(_ challenge: Challenge) {
        selectedChallenge = challenge
        HapticManager.selection()

        Task {
            do {
                self.standings = try await challengeService.getChallengeStandings(id: challenge.id)
            } catch {
                self.standings = []
            }
        }
    }

    public func dismissDetail() {
        selectedChallenge = nil
        standings = []
    }

    public func toggleJoin(for challenge: Challenge) async {
        isActionLoading = true
        do {
            if challenge.isJoined {
                try await challengeService.leaveChallenge(id: challenge.id)
                HapticManager.buttonTap()
            } else {
                try await challengeService.joinChallenge(id: challenge.id)
                HapticManager.celebration()
            }

            // Update local state
            if let index = challenges.firstIndex(where: { $0.id == challenge.id }) {
                challenges[index].isJoined.toggle()
                if selectedChallenge?.id == challenge.id {
                    selectedChallenge?.isJoined.toggle()
                }
            }
            isActionLoading = false
        } catch {
            isActionLoading = false
            HapticManager.error()
        }
    }
}
