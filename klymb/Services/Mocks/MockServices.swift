//
//  MockServices.swift
//  klymb
//
//  Mock service implementations for SwiftUI previews, testing, and offline dev.
//

import Foundation

public final class MockAuthService: AuthServiceProtocol {
    public var currentUserId: UUID? = UUID(uuidString: "11111111-1111-1111-1111-111111111111")
    public var isAuthenticated: Bool = true
    public var mockProfile: Profile? = Profile(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        username: "champion_dev",
        displayName: "Champion Dev",
        avatarPreset: "default",
        cityId: 1,
        cityName: "Mumbai",
        totalKP: 1250
    )

    public init(isAuthenticated: Bool = true) {
        self.isAuthenticated = isAuthenticated
    }

    public func signInWithApple(idToken: String, nonce: String) async throws -> Profile {
        isAuthenticated = true
        let profile = mockProfile ?? Profile(id: UUID(), username: "new_player")
        mockProfile = profile
        currentUserId = profile.id
        return profile
    }

    public func signOut() async throws {
        isAuthenticated = false
        currentUserId = nil
        mockProfile = nil
    }

    public func getCurrentProfile() async throws -> Profile? {
        guard isAuthenticated else { return nil }
        return mockProfile
    }
}

public final class MockProfileService: ProfileServiceProtocol {
    public var habits: [Habit] = [
        Habit(id: 1, key: "steps", displayName: "Steps", unit: "count", dailyKPCap: 150, isSelected: true),
        Habit(id: 2, key: "running", displayName: "Running", unit: "km", dailyKPCap: 200, isSelected: true),
        Habit(id: 3, key: "walking_distance", displayName: "Walking Distance", unit: "km", dailyKPCap: 120),
        Habit(id: 4, key: "workout", displayName: "Workout", unit: "minutes", dailyKPCap: 120, manualKPCap: 40, manualAllowed: true, isSelected: true),
        Habit(id: 5, key: "hydration", displayName: "Hydration", unit: "ml", dailyKPCap: 40, manualKPCap: 20, manualAllowed: true),
        Habit(id: 6, key: "sleep", displayName: "Sleep", unit: "hours", dailyKPCap: 50),
        Habit(id: 7, key: "mindfulness", displayName: "Mindfulness", unit: "minutes", dailyKPCap: 45, manualKPCap: 15, manualAllowed: true)
    ]

    public var streak: StreakInfo = StreakInfo(currentStreak: 7, longestStreak: 14, lastActiveDate: "2026-11-22", freezesRemaining: 2)

    public init() {}

    public func setUsername(_ username: String) async throws -> String {
        return username
    }

    public func setCity(cityId: Int64) async throws {}

    public func getCities() async throws -> [(id: Int64, name: String, state: String)] {
        return [
            (id: 1, name: "Mumbai", state: "Maharashtra"),
            (id: 2, name: "Delhi", state: "Delhi"),
            (id: 3, name: "Bengaluru", state: "Karnataka"),
            (id: 4, name: "Hyderabad", state: "Telangana")
        ]
    }

    public func getHabits() async throws -> [Habit] {
        return habits
    }

    public func setUserHabits(habitIds: [Int64]) async throws {
        for i in habits.indices {
            habits[i].isSelected = habitIds.contains(habits[i].id)
        }
    }

    public func getUserHabits() async throws -> [Habit] {
        return habits.filter { $0.isSelected }
    }

    public func getStreak() async throws -> StreakInfo {
        return streak
    }
}

public final class MockActivityService: ActivityServiceProtocol {
    public init() {}

    public func submitActivities(_ activities: [Activity]) async throws -> (accepted: Int, duplicate: Int, rejected: Int) {
        return (accepted: activities.count, duplicate: 0, rejected: 0)
    }

    public func getRecentActivities(limit: Int) async throws -> [Activity] {
        return [
            Activity(id: 1, habitId: 1, habitKey: "steps", quantity: 8420, unit: "count", startedAt: Date().addingTimeInterval(-3600), endedAt: Date(), kpEarned: 80),
            Activity(id: 2, habitId: 2, habitKey: "running", quantity: 5.2, unit: "km", startedAt: Date().addingTimeInterval(-7200), endedAt: Date().addingTimeInterval(-5400), kpEarned: 104)
        ]
    }
}

public final class MockLeaderboardService: LeaderboardServiceProtocol {
    public init() {}

    public func getLeaderboard(period: String, scope: String, limit: Int, offset: Int) async throws -> [LeaderboardEntry] {
        return [
            LeaderboardEntry(userId: UUID(), username: "speedy_runner", displayName: "Speedy", totalKP: 1840, rank: 1, cityRank: 1),
            LeaderboardEntry(userId: UUID(), username: "iron_yogi", displayName: "Iron Yogi", totalKP: 1620, rank: 2, cityRank: 2),
            LeaderboardEntry(userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, username: "champion_dev", displayName: "Champion Dev", totalKP: 1250, rank: 3, cityRank: 3, isCurrentUser: true),
            LeaderboardEntry(userId: UUID(), username: "trail_blazer", displayName: "Trail Blazer", totalKP: 980, rank: 4, cityRank: 4)
        ]
    }

    public func getMyRank(period: String, scope: String) async throws -> LeaderboardEntry? {
        return LeaderboardEntry(userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, username: "champion_dev", displayName: "Champion Dev", totalKP: 1250, rank: 3, cityRank: 3, isCurrentUser: true)
    }
}

public final class MockChallengeService: ChallengeServiceProtocol {
    public init() {}

    public func getActiveChallenges() async throws -> [Challenge] {
        return [
            Challenge(id: 1, type: "daily", title: "Daily 10K Steps", description: "Hit 10,000 steps before midnight", habitKey: "steps", target: 10000, rewardKP: 50, startAt: Date(), endAt: Date().addingTimeInterval(86400), progress: 7500, isJoined: true),
            Challenge(id: 2, type: "weekly", title: "Weekly 25K Runner", description: "Log 25 km of running this week", habitKey: "running", target: 25.0, rewardKP: 150, startAt: Date(), endAt: Date().addingTimeInterval(86400 * 5), progress: 12.4, isJoined: true)
        ]
    }

    public func joinChallenge(id: Int64) async throws {}

    public func getChallengeStandings(id: Int64) async throws -> [LeaderboardEntry] {
        return []
    }
}

public final class MockAchievementService: AchievementServiceProtocol {
    public init() {}

    public func getAchievements() async throws -> [Achievement] {
        return [
            Achievement(id: 1, key: "first_steps", displayName: "First Steps", description: "Submit your first activity", category: "milestone", tier: "bronze", rewardKP: 50, unlockedAt: Date()),
            Achievement(id: 2, key: "streak_7", displayName: "Week Warrior", description: "Reach a 7-day streak", category: "streak", tier: "silver", rewardKP: 100, unlockedAt: Date()),
            Achievement(id: 3, key: "century_run", displayName: "Century Club", description: "Run 100 km total", category: "distance", tier: "gold", rewardKP: 250, unlockedAt: nil)
        ]
    }
}

public final class MockSocialService: SocialServiceProtocol {
    public init() {}

    public func searchUsers(query: String) async throws -> [Profile] {
        return [
            Profile(id: UUID(), username: "alex_fitness", displayName: "Alex Fit", totalKP: 890),
            Profile(id: UUID(), username: "priya_runs", displayName: "Priya", totalKP: 1420)
        ]
    }

    public func getFriends() async throws -> [Profile] {
        return [
            Profile(id: UUID(), username: "priya_runs", displayName: "Priya", totalKP: 1420)
        ]
    }

    public func sendFriendRequest(targetUserId: UUID) async throws {}
    public func acceptFriendRequest(requesterId: UUID) async throws {}
}

public final class MockNotificationService: NotificationServiceProtocol {
    public init() {}
    public func registerDeviceToken(_ token: String, environment: String) async throws {}
    public func updatePreferences(overtaken: Bool?, challengeEnding: Bool?, streakRisk: Bool?) async throws {}
}
