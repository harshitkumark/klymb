//
//  HomeViewModel.swift
//  klymb
//
//  ViewModel powering the Home dashboard: KP count, streak, habit progress, and rival nudges.
//  (AGENTS.md Rule 15: SwiftUI + MVVM, Rule 16: Protocol DI, PRD §F20).
//

import SwiftUI
import Combine

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public var profile: Profile?
    @Published public var todayKP: Int = 0
    @Published public var dailyGoalKP: Int = 300
    @Published public var kpDeltaToday: Int = 0
    @Published public var streak: StreakInfo = StreakInfo(currentStreak: 0, longestStreak: 0)
    @Published public var habitProgresses: [DailyHabitProgress] = []
    @Published public var overtakeNudge: LeaderboardOvertakeNudge?
    @Published public var activeChallenge: Challenge?
    @Published public var isRefreshing: Bool = false
    @Published public var lastSyncDescription: String = "Just now"

    private let profileService: ProfileServiceProtocol
    private let syncService: SyncServiceProtocol
    private let challengeService: ChallengeServiceProtocol
    private let leaderboardService: LeaderboardServiceProtocol

    public init(container: AppContainerProtocol = AppContainer.mock) {
        self.profileService = container.profileService
        self.syncService = container.syncService
        self.challengeService = container.challengeService
        self.leaderboardService = container.leaderboardService

        loadInitialData()
    }

    public var goalProgressRatio: Double {
        guard dailyGoalKP > 0 else { return 0 }
        return min(1.0, Double(todayKP) / Double(dailyGoalKP))
    }

    public var greetingTitle: String {
        guard let profile = profile else { return "WELCOME BACK" }
        if let name = profile.displayName, !name.isEmpty {
            let first = name.components(separatedBy: " ").first ?? name
            return "HEY, \(first.uppercased())"
        }
        return "@\(profile.username.uppercased())"
    }

    public func loadInitialData() {
        Task {
            await reloadData()
        }
    }

    public func reloadData() async {
        do {
            async let streakTask = profileService.getStreak()
            async let progressTask = profileService.getTodayHabitProgress()
            async let challengesTask = challengeService.getActiveChallenges()
            async let rankTask = leaderboardService.getMyRankSummary(period: "daily", scope: "city")

            let (loadedStreak, progressResp, challenges, rankSummary) = try await (
                streakTask,
                progressTask,
                challengesTask,
                rankTask
            )

            self.streak = loadedStreak
            self.habitProgresses = mapHabitProgress(from: progressResp.habits)
            self.todayKP = progressResp.todayKP
            self.kpDeltaToday = progressResp.todayKP

            if let myRank = rankSummary.rank,
               let targetUser = rankSummary.nextUsername,
               rankSummary.kpToOvertake > 0 {
                self.overtakeNudge = LeaderboardOvertakeNudge(
                    cityName: profile?.cityName ?? "City",
                    currentRank: myRank,
                    rankChange: 0,
                    targetRivalUsername: targetUser,
                    kpNeededToOvertake: rankSummary.kpToOvertake
                )
            } else {
                self.overtakeNudge = nil
            }

            self.activeChallenge = challenges.first
            updateSyncLabel()
        } catch {
            // Preserve previously cached values if network fails
            updateSyncLabel()
        }
    }

    public func refreshDashboard() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        HapticManager.shared.buttonTap()

        do {
            _ = try await syncService.syncAllHabits()
            await reloadData()
            HapticManager.shared.selection()
        } catch {
            await reloadData()
        }
    }

    private func updateSyncLabel() {
        if let date = syncService.lastSyncedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            self.lastSyncDescription = formatter.localizedString(for: date, relativeTo: Date())
        } else {
            self.lastSyncDescription = "Not synced yet"
        }
    }

    private func mapHabitProgress(from items: [TodayHabitProgressItem]) -> [DailyHabitProgress] {
        return items.map { item in
            let (icon, target) = metadata(for: item.key)
            return DailyHabitProgress(
                id: item.habitId,
                key: item.key,
                displayName: item.displayName,
                iconName: icon,
                currentQuantity: item.currentQuantity,
                targetQuantity: target,
                unit: item.unit,
                kpEarnedToday: item.kpEarnedToday,
                dailyKPCap: item.dailyKPCap
            )
        }
    }

    private func metadata(for key: String) -> (icon: String, target: Double) {
        switch key {
        case "steps": return ("figure.walk", 10000)
        case "running": return ("figure.run", 5.0)
        case "walking_distance": return ("figure.walk.motion", 5.0)
        case "workout": return ("dumbbell.fill", 45)
        case "hydration": return ("drop.fill", 2500)
        case "sleep": return ("bed.double.fill", 8.0)
        case "mindfulness": return ("brain.head.profile", 20)
        default: return ("flame.fill", 100)
        }
    }
}
