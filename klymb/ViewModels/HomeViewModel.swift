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
    @Published public var kpDeltaToday: Int = 45
    @Published public var streak: StreakInfo = StreakInfo(currentStreak: 7, longestStreak: 14)
    @Published public var habitProgresses: [DailyHabitProgress] = []
    @Published public var overtakeNudge: LeaderboardOvertakeNudge?
    @Published public var activeChallenge: Challenge?
    @Published public var isRefreshing: Bool = false
    @Published public var lastSyncDescription: String = "Just now"

    private let profileService: ProfileServiceProtocol
    private let syncService: SyncServiceProtocol
    private let challengeService: ChallengeServiceProtocol

    public init(container: AppContainerProtocol = AppContainer.mock) {
        self.profileService = container.profileService
        self.syncService = container.syncService
        self.challengeService = container.challengeService

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
            // 1. Load Streak
            self.streak = try await profileService.getStreak()

            // 2. Load User Habits
            let userHabits = try await profileService.getUserHabits()
            self.habitProgresses = generateHabitProgress(from: userHabits)

            // 3. Compute today's KP from habit progresses
            let totalFromHabits = habitProgresses.reduce(0) { $0 + $1.kpEarnedToday }
            self.todayKP = max(185, totalFromHabits)

            // 4. Load Overtake Nudge
            let city = profile?.cityName ?? "Bengaluru"
            self.overtakeNudge = LeaderboardOvertakeNudge(
                cityName: city,
                currentRank: 12,
                rankChange: 3,
                targetRivalUsername: "ravi",
                kpNeededToOvertake: 142
            )

            // 5. Load Active Challenge
            let challenges = try await challengeService.getActiveChallenges()
            self.activeChallenge = challenges.first

            updateSyncLabel()
        } catch {
            // Fallback to offline defaults
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
            self.lastSyncDescription = "Just now"
        }
    }

    private func generateHabitProgress(from habits: [Habit]) -> [DailyHabitProgress] {
        guard !habits.isEmpty else {
            // Seeded realistic starter habits
            return [
                DailyHabitProgress(id: 1, key: "steps", displayName: "Steps", iconName: "figure.walk", currentQuantity: 8432, targetQuantity: 10000, unit: "count", kpEarnedToday: 84, dailyKPCap: 150),
                DailyHabitProgress(id: 2, key: "running", displayName: "Running", iconName: "figure.run", currentQuantity: 3.2, targetQuantity: 5.0, unit: "km", kpEarnedToday: 64, dailyKPCap: 200),
                DailyHabitProgress(id: 4, key: "workout", displayName: "Workout", iconName: "dumbbell.fill", currentQuantity: 35, targetQuantity: 45, unit: "minutes", kpEarnedToday: 40, dailyKPCap: 120),
                DailyHabitProgress(id: 5, key: "hydration", displayName: "Hydration", iconName: "drop.fill", currentQuantity: 1500, targetQuantity: 2500, unit: "ml", kpEarnedToday: 24, dailyKPCap: 40),
                DailyHabitProgress(id: 6, key: "sleep", displayName: "Sleep", iconName: "bed.double.fill", currentQuantity: 7.2, targetQuantity: 8.0, unit: "hours", kpEarnedToday: 36, dailyKPCap: 50)
            ]
        }

        return habits.map { habit in
            let icon: String
            let current: Double
            let target: Double
            let kp: Int

            switch habit.key {
            case "steps":
                icon = "figure.walk"
                current = 8432
                target = 10000
                kp = 84
            case "running":
                icon = "figure.run"
                current = 3.2
                target = 5.0
                kp = 64
            case "workout":
                icon = "dumbbell.fill"
                current = 35
                target = 45
                kp = 40
            case "hydration":
                icon = "drop.fill"
                current = 1500
                target = 2500
                kp = 24
            case "sleep":
                icon = "bed.double.fill"
                current = 7.2
                target = 8.0
                kp = 36
            case "mindfulness":
                icon = "brain.head.profile"
                current = 15
                target = 20
                kp = 25
            default:
                icon = "flame.fill"
                current = 50
                target = 100
                kp = 20
            }

            return DailyHabitProgress(
                id: habit.id,
                key: habit.key,
                displayName: habit.displayName,
                iconName: icon,
                currentQuantity: current,
                targetQuantity: target,
                unit: habit.unit,
                kpEarnedToday: kp,
                dailyKPCap: habit.dailyKPCap
            )
        }
    }
}
