//
//  SupabaseServices.swift
//  klymb
//
//  Live Supabase implementations for all service protocols.
//  Communicates with Postgres RPCs & Auth via SupabaseClient (AGENTS.md Rules 1, 2, 14, 16).
//

import Foundation

// MARK: - 1. Auth Service
public final class SupabaseAuthService: AuthServiceProtocol {
    private let client: SupabaseClient
    public private(set) var currentUserId: UUID?
    public private(set) var isAuthenticated: Bool = false

    public init(client: SupabaseClient = .shared) {
        self.client = client
    }

    public func signInWithApple(idToken: String, nonce: String) async throws -> Profile {
        let session = try await client.signInWithApple(idToken: idToken, nonce: nonce)
        self.currentUserId = session.user.id
        self.isAuthenticated = true
        if let profile = try await fetchProfile(for: session.user.id) {
            return profile
        }
        throw APIError.notFound("Profile")
    }

    public func signInWithEmail(email: String, password: String) async throws -> Profile {
        let session = try await client.signInWithEmail(email: email, password: password)
        self.currentUserId = session.user.id
        self.isAuthenticated = true
        if let profile = try await fetchProfile(for: session.user.id) {
            return profile
        }
        throw APIError.notFound("Profile")
    }

    public func signUpWithEmail(email: String, password: String) async throws -> Profile {
        let session = try await client.signUpWithEmail(email: email, password: password)
        self.currentUserId = session.user.id
        self.isAuthenticated = true
        if let profile = try await fetchProfile(for: session.user.id) {
            return profile
        }
        throw APIError.notFound("Profile")
    }

    public func signOut() async throws {
        await client.signOut()
        self.currentUserId = nil
        self.isAuthenticated = false
    }

    public func getCurrentProfile() async throws -> Profile? {
        guard let session = await client.currentSession else {
            self.currentUserId = nil
            self.isAuthenticated = false
            return nil
        }
        self.currentUserId = session.user.id
        self.isAuthenticated = true
        do {
            return try await fetchProfile(for: session.user.id)
        } catch APIError.unauthorized {
            self.currentUserId = nil
            self.isAuthenticated = false
            return nil
        }
    }

    private func fetchProfile(for userId: UUID) async throws -> Profile? {
        let profile: Profile? = try await client.rpc("get_my_profile")
        if let profile = profile {
            CacheManager.shared.set(profile, forKey: CacheKeys.profile, ttl: 300)
        }
        return profile
    }
}

// MARK: - 2. Profile & Habit Service
public final class SupabaseProfileService: ProfileServiceProtocol {
    private let client: SupabaseClient
    private var cachedProfile: Profile?

    public init(client: SupabaseClient = .shared) {
        self.client = client
    }

    public func setUsername(_ username: String) async throws -> String {
        struct SetUsernameResponse: Decodable {
            let success: Bool?
            let username: String
        }
        let res: SetUsernameResponse = try await client.rpc("set_username", params: ["new_username": username])
        return res.username
    }

    public func setCity(cityId: Int64) async throws {
        try await client.rpcVoid("set_city", params: ["new_city_id": cityId])
    }

    public func getCities() async throws -> [CityItem] {
        let cities: [CityItem] = try await client.select(
            "cities",
            queryItems: [
                URLQueryItem(name: "select", value: "id,name,country"),
                URLQueryItem(name: "order", value: "id.asc")
            ]
        )
        return cities
    }

    public func getHabits() async throws -> [Habit] {
        let habits: [Habit] = try await client.rpc("get_my_habits")
        CacheManager.shared.set(habits, forKey: CacheKeys.habits, ttl: 300)
        return habits
    }

    public func setUserHabits(habitIds: [Int64]) async throws {
        try await client.rpcVoid("set_user_habits", params: ["habit_ids": habitIds])
    }

    public func getUserHabits() async throws -> [Habit] {
        let all = try await getHabits()
        return all.filter { $0.isSelected }
    }

    public func getTodayHabitProgress() async throws -> TodayHabitProgressResponse {
        let res: TodayHabitProgressResponse = try await client.rpc("get_today_habit_progress")
        return res
    }

    public func updateProfile(displayName: String?, avatarPreset: String?) async throws -> Profile {
        guard let uid = await client.currentUserId else {
            throw APIError.unauthorized
        }

        var body: [String: Any] = ["updated_at": SupabaseClient.iso8601Formatter.string(from: Date())]
        if let displayName = displayName {
            body["display_name"] = displayName
        } else {
            body["display_name"] = NSNull()
        }
        if let avatarPreset = avatarPreset {
            body["avatar_preset"] = avatarPreset
        }

        let _: [Profile] = try await client.patch(
            "profiles",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(uid.uuidString)")],
            body: body
        )

        guard let fullProfile: Profile = try await client.rpc("get_my_profile") else {
            throw APIError.notFound("Profile")
        }
        self.cachedProfile = fullProfile
        return fullProfile
    }

    public func getStreak() async throws -> StreakInfo {
        let streak: StreakInfo = try await client.rpc("get_my_streak")
        CacheManager.shared.set(streak, forKey: CacheKeys.streak, ttl: 300)
        return streak
    }

    public func getCityCooldown() async throws -> CityChangeCooldown {
        let profile: Profile? = try await client.rpc("get_my_profile")
        return CityChangeCooldown(lastChangedAt: profile?.cityChangedAt)
    }

    public func exportUserData() async throws -> String {
        let raw: AnyDecodableJSON = try await client.rpc("export_my_data")
        let data = try JSONSerialization.data(withJSONObject: raw.value, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    public func requestAccountDeletion() async throws -> AccountDeletionInfo {
        struct DeletionResponse: Decodable {
            let scheduledFor: Date?
            enum CodingKeys: String, CodingKey {
                case scheduledFor = "scheduled_for"
            }
        }
        let res: DeletionResponse = try await client.rpc("request_account_deletion")
        return AccountDeletionInfo(scheduledFor: res.scheduledFor ?? Date().addingTimeInterval(30 * 86400))
    }

    public func cancelAccountDeletion() async throws {
        try await client.rpcVoid("cancel_account_deletion")
    }
}

// MARK: - 3. Activity Service
public final class SupabaseActivityService: ActivityServiceProtocol {
    private let client: SupabaseClient

    public init(client: SupabaseClient = .shared) {
        self.client = client
    }

    public func submitActivities(_ activities: [Activity]) async throws -> (accepted: Int, duplicate: Int, rejected: Int) {
        guard !activities.isEmpty else { return (0, 0, 0) }

        let samplesPayload: [[String: Any]] = activities.map { act in
            var dict: [String: Any] = [
                "habit_key": act.habitKey,
                "quantity": act.quantity,
                "started_at": SupabaseClient.iso8601Formatter.string(from: act.startedAt),
                "ended_at": SupabaseClient.iso8601Formatter.string(from: act.endedAt),
                "source": act.source,
                "was_user_entered": act.wasUserEntered
            ]
            if let sampleId = act.sourceSampleId {
                dict["source_sample_id"] = sampleId
            }
            if let deviceInfo = act.deviceInfo {
                dict["device_info"] = deviceInfo
            }
            return dict
        }

        struct SubmitResultRow: Decodable {
            let status: String
        }

        let results: [SubmitResultRow] = try await client.rpc("submit_activities", params: ["samples": samplesPayload])
        var accepted = 0
        var duplicate = 0
        var rejected = 0
        for row in results {
            switch row.status {
            case "accepted": accepted += 1
            case "duplicate": duplicate += 1
            default: rejected += 1
            }
        }
        return (accepted, duplicate, rejected)
    }

    public func getRecentActivities(limit: Int) async throws -> [Activity] {
        struct ActivityRow: Decodable {
            let id: Int64
            let habitId: Int64
            let quantity: Double
            let startedAt: Date
            let endedAt: Date
            let source: String
            let sourceSampleId: String?
            let wasUserEntered: Bool
            let habits: HabitMeta?

            struct HabitMeta: Decodable {
                let key: String
                let unit: String
            }

            enum CodingKeys: String, CodingKey {
                case id, quantity, source, habits
                case habitId = "habit_id"
                case startedAt = "started_at"
                case endedAt = "ended_at"
                case sourceSampleId = "source_sample_id"
                case wasUserEntered = "was_user_entered"
            }
        }

        let rows: [ActivityRow] = try await client.select(
            "activities",
            queryItems: [
                URLQueryItem(name: "select", value: "id,habit_id,quantity,started_at,ended_at,source,source_sample_id,was_user_entered,habits(key,unit)"),
                URLQueryItem(name: "order", value: "started_at.desc"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )

        return rows.map {
            Activity(
                id: $0.id,
                habitId: $0.habitId,
                habitKey: $0.habits?.key ?? "steps",
                quantity: $0.quantity,
                unit: $0.habits?.unit ?? "units",
                startedAt: $0.startedAt,
                endedAt: $0.endedAt,
                source: $0.source,
                sourceSampleId: $0.sourceSampleId,
                wasUserEntered: $0.wasUserEntered
            )
        }
    }
}

// MARK: - 4. Leaderboard Service
public final class SupabaseLeaderboardService: LeaderboardServiceProtocol {
    private let client: SupabaseClient

    public init(client: SupabaseClient = .shared) {
        self.client = client
    }

    public func getLeaderboard(period: String, scope: String, limit: Int, offset: Int) async throws -> [LeaderboardEntry] {
        let uid = await client.currentUserId
        var entries: [LeaderboardEntry] = try await client.rpc(
            "get_leaderboard",
            params: [
                "p_scope": scope,
                "p_period": period,
                "p_limit": limit,
                "p_offset": offset
            ]
        )
        for i in entries.indices {
            entries[i].isCurrentUser = (entries[i].userId == uid)
        }
        return entries
    }

    public func getMyRank(period: String, scope: String) async throws -> LeaderboardEntry? {
        guard let uid = await client.currentUserId else { return nil }
        let summary = try await getMyRankSummary(period: period, scope: scope)
        guard let rank = summary.rank else { return nil }

        let profile: Profile? = try await client.rpc("get_my_profile")
        return LeaderboardEntry(
            userId: uid,
            username: profile?.username ?? "you",
            displayName: profile?.displayName,
            avatarPreset: profile?.avatarPreset ?? "default",
            totalKP: summary.kp,
            rank: rank,
            cityRank: scope == "city" ? rank : nil,
            isCurrentUser: true,
            rankChange: 0,
            cityName: profile?.cityName
        )
    }

    public func getMyRankSummary(period: String, scope: String) async throws -> MyRankSummary {
        struct RankRPCResponse: Decodable {
            let rank: Int?
            let kp: Int?
            let nextUser: NextUser?
            let kpToOvertake: Int?

            struct NextUser: Decodable {
                let username: String
                let rank: Int
            }

            enum CodingKeys: String, CodingKey {
                case rank, kp
                case nextUser = "next_user"
                case kpToOvertake = "kp_to_overtake"
            }
        }

        let res: RankRPCResponse = try await client.rpc(
            "get_my_rank",
            params: [
                "p_scope": scope,
                "p_period": period
            ]
        )
        return MyRankSummary(
            rank: res.rank,
            kp: res.kp ?? 0,
            nextUsername: res.nextUser?.username,
            kpToOvertake: res.kpToOvertake ?? 0
        )
    }
}

// MARK: - 5. Challenge Service
public final class SupabaseChallengeService: ChallengeServiceProtocol {
    private let client: SupabaseClient

    public init(client: SupabaseClient = .shared) {
        self.client = client
    }

    public func getActiveChallenges() async throws -> [Challenge] {
        let challenges: [Challenge] = try await client.rpc("get_active_challenges")
        CacheManager.shared.set(challenges, forKey: CacheKeys.challenges, ttl: 300)
        return challenges
    }

    public func joinChallenge(id: Int64) async throws {
        try await client.rpcVoid("join_challenge", params: ["p_challenge_id": id])
    }

    public func leaveChallenge(id: Int64) async throws {
        try await client.rpcVoid("leave_challenge", params: ["p_challenge_id": id])
    }

    public func getChallengeStandings(id: Int64) async throws -> [LeaderboardEntry] {
        struct StandingRow: Decodable {
            let rank: Int
            let userId: UUID
            let username: String
            let avatarPreset: String?
            let currentValue: Double

            enum CodingKeys: String, CodingKey {
                case rank, username
                case userId = "user_id"
                case avatarPreset = "avatar_preset"
                case currentValue = "current_value"
            }
        }

        let uid = await client.currentUserId
        let rows: [StandingRow] = try await client.rpc(
            "get_challenge_standings",
            params: ["p_challenge_id": id, "p_limit": 50, "p_offset": 0]
        )

        return rows.map {
            LeaderboardEntry(
                userId: $0.userId,
                username: $0.username,
                displayName: nil,
                avatarPreset: $0.avatarPreset ?? "default",
                totalKP: Int($0.currentValue),
                rank: $0.rank,
                isCurrentUser: $0.userId == uid
            )
        }
    }
}

// MARK: - 6. Achievement Service
public final class SupabaseAchievementService: AchievementServiceProtocol {
    private let client: SupabaseClient

    public init(client: SupabaseClient = .shared) {
        self.client = client
    }

    public func getAchievements() async throws -> [Achievement] {
        let list: [Achievement] = try await client.rpc("get_my_achievements")
        return list
    }
}

// MARK: - 7. Social Service
public final class SupabaseSocialService: SocialServiceProtocol {
    private let client: SupabaseClient

    public init(client: SupabaseClient = .shared) {
        self.client = client
    }

    public func searchUsers(query: String) async throws -> [FriendItem] {
        guard query.trimmingCharacters(in: .whitespaces).count >= 2 else { return [] }
        return try await client.rpc("search_users_with_status", params: ["p_query": query, "p_limit": 20])
    }

    public func getFriends() async throws -> [FriendItem] {
        return try await client.rpc("get_friends_with_stats", params: ["p_limit": 50, "p_offset": 0])
    }

    public func getIncomingRequests() async throws -> [FriendItem] {
        return try await client.rpc("get_incoming_friend_requests")
    }

    public func sendFriendRequest(targetUserId: UUID) async throws {
        try await client.rpcVoid("send_friend_request", params: ["p_target_user_id": targetUserId.uuidString])
    }

    public func acceptFriendRequest(requesterId: UUID) async throws {
        try await client.rpcVoid("accept_friend_request", params: ["p_requester_user_id": requesterId.uuidString])
    }

    public func declineFriendRequest(requesterId: UUID) async throws {
        try await client.rpcVoid("decline_friend_request", params: ["p_requester_user_id": requesterId.uuidString])
    }

    public func cheerFriend(targetUserId: UUID) async throws {
        try await client.rpcVoid("cheer_friend", params: ["p_target_user_id": targetUserId.uuidString])
    }
}

// MARK: - 8. Notification Service
public final class SupabaseNotificationService: NotificationServiceProtocol {
    private let client: SupabaseClient

    public init(client: SupabaseClient = .shared) {
        self.client = client
    }

    public func registerDeviceToken(_ token: String, environment: String) async throws {
        try await client.rpcVoid(
            "register_device_token",
            params: ["p_apns_token": token, "p_environment": environment]
        )
    }

    public func updatePreferences(overtaken: Bool?, challengeEnding: Bool?, streakRisk: Bool?) async throws {
        var params: [String: Any] = [:]
        if let o = overtaken { params["p_overtaken"] = o }
        if let c = challengeEnding { params["p_challenge_ending"] = c }
        if let s = streakRisk { params["p_streak_risk"] = s }
        try await client.rpcVoid("update_notification_preferences", params: params)
    }

    public func getPreferences() async throws -> NotificationPreferences {
        return try await client.rpc("get_my_notification_preferences")
    }
}

// MARK: - Generic JSON Helper for export_my_data()
private struct AnyDecodableJSON: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let str = try? container.decode(String.self) {
            self.value = str
        } else if let arr = try? container.decode([AnyDecodableJSON].self) {
            self.value = arr.map { $0.value }
        } else if let dict = try? container.decode([String: AnyDecodableJSON].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            self.value = [:]
        }
    }
}
