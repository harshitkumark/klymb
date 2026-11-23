//
//  MockServices.swift
//  klymb
//
//  Mock service implementations for SwiftUI previews, testing, and offline dev.
//

import Foundation

public final class MockAuthService: AuthServiceProtocol {
    public var currentUserId: UUID? = nil
    public var isAuthenticated: Bool = false
    public var mockProfile: Profile? = nil

    public init(isAuthenticated: Bool = false) {
        self.isAuthenticated = isAuthenticated
    }

    public func signInWithApple(idToken: String, nonce: String) async throws -> Profile {
        isAuthenticated = true
        let profile = Profile(
            id: UUID(),
            username: "user_\(Int.random(in: 100000...999999))",
            displayName: nil,
            avatarPreset: "default",
            cityId: nil
        )
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

    public var currentProfile: Profile? = Profile(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        username: "champion_dev",
        displayName: "Champion Dev",
        avatarPreset: "default",
        cityId: 1,
        cityName: "Bengaluru",
        totalKP: 1250
    )

    public init() {}

    public func setUsername(_ username: String) async throws -> String {
        currentProfile?.username = username
        return username
    }

    public func setCity(cityId: Int64) async throws {
        currentProfile?.cityId = cityId
        let cities = try await getCities()
        if let city = cities.first(where: { $0.id == cityId }) {
            currentProfile?.cityName = city.name
        }
    }

    public func getCities() async throws -> [CityItem] {
        return [
            CityItem(id: 1, name: "Bengaluru", country: "India"),
            CityItem(id: 2, name: "Mumbai", country: "India"),
            CityItem(id: 3, name: "Delhi", country: "India"),
            CityItem(id: 4, name: "Hyderabad", country: "India"),
            CityItem(id: 5, name: "Chennai", country: "India"),
            CityItem(id: 6, name: "Kolkata", country: "India"),
            CityItem(id: 7, name: "Pune", country: "India"),
            CityItem(id: 8, name: "Ahmedabad", country: "India"),
            CityItem(id: 9, name: "Jaipur", country: "India"),
            CityItem(id: 10, name: "Surat", country: "India"),
            CityItem(id: 11, name: "Lucknow", country: "India"),
            CityItem(id: 12, name: "Chandigarh", country: "India"),
            CityItem(id: 13, name: "Kochi", country: "India"),
            CityItem(id: 14, name: "Indore", country: "India"),
            CityItem(id: 15, name: "Bhopal", country: "India"),
            CityItem(id: 16, name: "Nagpur", country: "India"),
            CityItem(id: 17, name: "Patna", country: "India"),
            CityItem(id: 18, name: "Bhubaneswar", country: "India"),
            CityItem(id: 19, name: "Coimbatore", country: "India"),
            CityItem(id: 20, name: "Visakhapatnam", country: "India"),
            CityItem(id: 21, name: "Gurugram", country: "India"),
            CityItem(id: 22, name: "Noida", country: "India"),
            CityItem(id: 23, name: "Singapore", country: "Singapore"),
            CityItem(id: 24, name: "Dubai", country: "United Arab Emirates"),
            CityItem(id: 25, name: "London", country: "United Kingdom"),
            CityItem(id: 26, name: "New York", country: "United States"),
            CityItem(id: 27, name: "San Francisco", country: "United States"),
            CityItem(id: 28, name: "Tokyo", country: "Japan"),
            CityItem(id: 29, name: "Sydney", country: "Australia"),
            CityItem(id: 30, name: "Toronto", country: "Canada")
        ]
    }

    public func updateProfile(displayName: String?, avatarPreset: String?) async throws -> Profile {
        if var profile = currentProfile {
            if let displayName = displayName { profile.displayName = displayName }
            if let avatarPreset = avatarPreset { profile.avatarPreset = avatarPreset }
            profile.updatedAt = Date()
            currentProfile = profile
            return profile
        }
        let profile = Profile(
            id: UUID(),
            username: "champion_dev",
            displayName: displayName,
            avatarPreset: avatarPreset ?? "default"
        )
        currentProfile = profile
        return profile
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
        let city = (scope == "city") ? "San Francisco" : "New York"
        return [
            LeaderboardEntry(userId: UUID(), username: "speedy_runner", displayName: "Speedy", avatarPreset: "sprinter", totalKP: 1840, rank: 1, cityRank: 1, isCurrentUser: false, rankChange: 2, cityName: city),
            LeaderboardEntry(userId: UUID(), username: "iron_yogi", displayName: "Iron Yogi", avatarPreset: "zen", totalKP: 1620, rank: 2, cityRank: 2, isCurrentUser: false, rankChange: -1, cityName: city),
            LeaderboardEntry(userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, username: "champion_dev", displayName: "Champion Dev", avatarPreset: "star", totalKP: 1250, rank: 3, cityRank: 3, isCurrentUser: true, rankChange: 1, cityName: city),
            LeaderboardEntry(userId: UUID(), username: "trail_blazer", displayName: "Trail Blazer", avatarPreset: "climber", totalKP: 1120, rank: 4, cityRank: 4, isCurrentUser: false, rankChange: 3, cityName: "Austin"),
            LeaderboardEntry(userId: UUID(), username: "cyclone_kai", displayName: "Kai C.", avatarPreset: "cyclist", totalKP: 980, rank: 5, cityRank: 5, isCurrentUser: false, rankChange: -2, cityName: "Seattle"),
            LeaderboardEntry(userId: UUID(), username: "apex_maya", displayName: "Maya Apex", avatarPreset: "bolt", totalKP: 890, rank: 6, cityRank: 6, isCurrentUser: false, rankChange: 0, cityName: "London"),
            LeaderboardEntry(userId: UUID(), username: "shield_sam", displayName: "Sam Titan", avatarPreset: "shield", totalKP: 810, rank: 7, cityRank: 7, isCurrentUser: false, rankChange: 1, cityName: "Berlin"),
            LeaderboardEntry(userId: UUID(), username: "swift_claire", displayName: "Claire", avatarPreset: "runner", totalKP: 760, rank: 8, cityRank: 8, isCurrentUser: false, rankChange: -1, cityName: "Tokyo"),
            LeaderboardEntry(userId: UUID(), username: "zen_marcus", displayName: "Marcus M.", avatarPreset: "zen", totalKP: 710, rank: 9, cityRank: 9, isCurrentUser: false, rankChange: 4, cityName: "Toronto"),
            LeaderboardEntry(userId: UUID(), username: "pulse_leila", displayName: "Leila P.", avatarPreset: "sprinter", totalKP: 650, rank: 10, cityRank: 10, isCurrentUser: false, rankChange: 0, cityName: "Paris")
        ]
    }

    public func getMyRank(period: String, scope: String) async throws -> LeaderboardEntry? {
        return LeaderboardEntry(userId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, username: "champion_dev", displayName: "Champion Dev", avatarPreset: "star", totalKP: 1250, rank: 3, cityRank: 3, isCurrentUser: true, rankChange: 1, cityName: "San Francisco")
    }
}

public final class MockChallengeService: ChallengeServiceProtocol {
    private var challenges: [Challenge] = [
        Challenge(id: 1, type: "daily", title: "Daily 10K Steps", description: "Hit 10,000 steps today to claim your daily badge.", habitKey: "steps", target: 10000, rewardKP: 50, startAt: Date(), endAt: Date().addingTimeInterval(28800), progress: 7500, isJoined: true),
        Challenge(id: 2, type: "daily", title: "Hydration Streak", description: "Log 3,000 ml of pure water intake.", habitKey: "water", target: 3000, rewardKP: 40, startAt: Date(), endAt: Date().addingTimeInterval(36000), progress: 1750, isJoined: true),
        Challenge(id: 3, type: "weekly", title: "Weekend 25K Runner", description: "Log 25 km of running this week across sessions.", habitKey: "running", target: 25.0, rewardKP: 150, startAt: Date(), endAt: Date().addingTimeInterval(86400 * 4), progress: 14.5, isJoined: true),
        Challenge(id: 4, type: "weekly", title: "Zen Master", description: "Complete 60 minutes of focused mindfulness or meditation.", habitKey: "mindfulness", target: 60.0, rewardKP: 80, startAt: Date(), endAt: Date().addingTimeInterval(86400 * 5), progress: 30.0, isJoined: false),
        Challenge(id: 5, type: "weekly", title: "Century Cyclist", description: "Pedal 50 km on road or indoor trainer.", habitKey: "cycling", target: 50.0, rewardKP: 180, startAt: Date(), endAt: Date().addingTimeInterval(86400 * 6), progress: 0.0, isJoined: false),
        Challenge(id: 6, type: "community", title: "SF City 1M Step March", description: "San Francisco athletes uniting for 1,000,000 total steps.", habitKey: "steps", target: 1000000, rewardKP: 300, startAt: Date(), endAt: Date().addingTimeInterval(86400 * 10), progress: 684200, isJoined: true)
    ]

    public init() {}

    public func getActiveChallenges() async throws -> [Challenge] {
        return challenges
    }

    public func joinChallenge(id: Int64) async throws {
        if let idx = challenges.firstIndex(where: { $0.id == id }) {
            challenges[idx].isJoined = true
        }
    }

    public func leaveChallenge(id: Int64) async throws {
        if let idx = challenges.firstIndex(where: { $0.id == id }) {
            challenges[idx].isJoined = false
        }
    }

    public func getChallengeStandings(id: Int64) async throws -> [LeaderboardEntry] {
        return [
            LeaderboardEntry(userId: UUID(), username: "speedy_runner", displayName: "Speedy", totalKP: 1840, rank: 1),
            LeaderboardEntry(userId: UUID(), username: "iron_yogi", displayName: "Iron Yogi", totalKP: 1620, rank: 2),
            LeaderboardEntry(userId: UUID(), username: "champion_dev", displayName: "You", totalKP: 1250, rank: 3, isCurrentUser: true)
        ]
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
