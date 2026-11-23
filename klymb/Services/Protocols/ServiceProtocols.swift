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
public struct CityItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: Int64
    public let name: String
    public let country: String

    public init(id: Int64, name: String, country: String) {
        self.id = id
        self.name = name
        self.country = country
    }
}

public protocol ProfileServiceProtocol: AnyObject {
    func setUsername(_ username: String) async throws -> String
    func setCity(cityId: Int64) async throws
    func getCities() async throws -> [CityItem]
    func getHabits() async throws -> [Habit]
    func setUserHabits(habitIds: [Int64]) async throws
    func getUserHabits() async throws -> [Habit]
    func updateProfile(displayName: String?, avatarPreset: String?) async throws -> Profile
    func getStreak() async throws -> StreakInfo
    func getCityCooldown() async throws -> CityChangeCooldown
    func exportUserData() async throws -> String
    func requestAccountDeletion() async throws -> AccountDeletionInfo
    func cancelAccountDeletion() async throws
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
    func leaveChallenge(id: Int64) async throws
    func getChallengeStandings(id: Int64) async throws -> [LeaderboardEntry]
}

// MARK: - Achievement Service Protocol
public protocol AchievementServiceProtocol: AnyObject {
    func getAchievements() async throws -> [Achievement]
}

// MARK: - Social Service Protocol
public protocol SocialServiceProtocol: AnyObject {
    func searchUsers(query: String) async throws -> [FriendItem]
    func getFriends() async throws -> [FriendItem]
    func getIncomingRequests() async throws -> [FriendItem]
    func sendFriendRequest(targetUserId: UUID) async throws
    func acceptFriendRequest(requesterId: UUID) async throws
    func declineFriendRequest(requesterId: UUID) async throws
    func cheerFriend(targetUserId: UUID) async throws
}

// MARK: - Notification Service Protocol
public protocol NotificationServiceProtocol: AnyObject {
    func registerDeviceToken(_ token: String, environment: String) async throws
    func updatePreferences(overtaken: Bool?, challengeEnding: Bool?, streakRisk: Bool?) async throws
    func getPreferences() async throws -> NotificationPreferences
}

// MARK: - Analytics Service Protocol
public protocol AnalyticsServiceProtocol: AnyObject {
    func track(event: AnalyticsEvent)
    func identify(userId: UUID)
    func reset()
}
