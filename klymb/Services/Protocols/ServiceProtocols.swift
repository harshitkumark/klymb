//
//  ServiceProtocols.swift
//  klymb
//
//  Protocols for all application services (AGENTS.md Rule 16).
//

import Foundation

// MARK: - Auth Service Protocol
public protocol AuthServiceProtocol: AnyObject {
    var currentUserId: UUID? { get }
    var isAuthenticated: Bool { get }

    func signInWithApple(idToken: String, nonce: String) async throws -> Profile
    func signOut() async throws
    func getCurrentProfile() async throws -> Profile?
}

// MARK: - Profile & Habit Service Protocol
public protocol ProfileServiceProtocol: AnyObject {
    func setUsername(_ username: String) async throws -> String
    func setCity(cityId: Int64) async throws
    func getCities() async throws -> [(id: Int64, name: String, state: String)]
    func getHabits() async throws -> [Habit]
    func setUserHabits(habitIds: [Int64]) async throws
    func getUserHabits() async throws -> [Habit]
    func getStreak() async throws -> StreakInfo
}

// MARK: - Activity Service Protocol
public protocol ActivityServiceProtocol: AnyObject {
    func submitActivities(_ activities: [Activity]) async throws -> (accepted: Int, duplicate: Int, rejected: Int)
    func getRecentActivities(limit: Int) async throws -> [Activity]
}

// MARK: - Leaderboard Service Protocol
public protocol LeaderboardServiceProtocol: AnyObject {
    func getLeaderboard(period: String, scope: String, limit: Int, offset: Int) async throws -> [LeaderboardEntry]
    func getMyRank(period: String, scope: String) async throws -> LeaderboardEntry?
}

// MARK: - Challenge Service Protocol
public protocol ChallengeServiceProtocol: AnyObject {
    func getActiveChallenges() async throws -> [Challenge]
    func joinChallenge(id: Int64) async throws
    func getChallengeStandings(id: Int64) async throws -> [LeaderboardEntry]
}

// MARK: - Achievement Service Protocol
public protocol AchievementServiceProtocol: AnyObject {
    func getAchievements() async throws -> [Achievement]
}

// MARK: - Social Service Protocol
public protocol SocialServiceProtocol: AnyObject {
    func searchUsers(query: String) async throws -> [Profile]
    func getFriends() async throws -> [Profile]
    func sendFriendRequest(targetUserId: UUID) async throws
    func acceptFriendRequest(requesterId: UUID) async throws
}

// MARK: - Notification Service Protocol
public protocol NotificationServiceProtocol: AnyObject {
    func registerDeviceToken(_ token: String, environment: String) async throws
    func updatePreferences(overtaken: Bool?, challengeEnding: Bool?, streakRisk: Bool?) async throws
}
