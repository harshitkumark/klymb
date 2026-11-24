//
//  GameModels.swift
//  klymb
//
//  Activity, Streak, Leaderboard, Challenge, and Achievement models.
//

import Foundation

public struct Activity: Identifiable, Codable, Equatable {
    public let id: Int64?
    public let habitId: Int64
    public let habitKey: String
    public let quantity: Double
    public let unit: String
    public let startedAt: Date
    public let endedAt: Date
    public let source: String // "healthkit" or "manual"
    public let sourceSampleId: String?
    public let wasUserEntered: Bool
    public var kpEarned: Int?
    public var deviceInfo: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case habitKey = "habit_key"
        case quantity
        case unit
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case source
        case sourceSampleId = "source_sample_id"
        case wasUserEntered = "was_user_entered"
        case kpEarned = "kp_earned"
        case deviceInfo = "device_info"
    }

    public init(
        id: Int64? = nil,
        habitId: Int64,
        habitKey: String,
        quantity: Double,
        unit: String,
        startedAt: Date,
        endedAt: Date,
        source: String = "healthkit",
        sourceSampleId: String? = nil,
        wasUserEntered: Bool = false,
        kpEarned: Int? = nil,
        deviceInfo: [String: String]? = nil
    ) {
        self.id = id
        self.habitId = habitId
        self.habitKey = habitKey
        self.quantity = quantity
        self.unit = unit
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.source = source
        self.sourceSampleId = sourceSampleId
        self.wasUserEntered = wasUserEntered
        self.kpEarned = kpEarned
        self.deviceInfo = deviceInfo
    }
}

public struct StreakInfo: Codable, Equatable {
    public let currentStreak: Int
    public let longestStreak: Int
    public let lastActiveDate: String?
    public let freezesRemaining: Int

    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastActiveDate = "last_active_date"
        case freezesRemaining = "freezes_remaining"
    }

    public init(
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastActiveDate: String? = nil,
        freezesRemaining: Int = 2
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastActiveDate = lastActiveDate
        self.freezesRemaining = freezesRemaining
    }
}

public struct LeaderboardEntry: Identifiable, Codable, Equatable {
    public var id: UUID { userId }
    public let userId: UUID
    public let username: String
    public let displayName: String?
    public let avatarPreset: String
    public let totalKP: Int
    public let rank: Int
    public let cityRank: Int?
    public var isCurrentUser: Bool
    public var rankChange: Int
    public var cityName: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case avatarPreset = "avatar_preset"
        case totalKP = "kp"
        case rank
        case cityRank = "city_rank"
        case isCurrentUser = "is_current_user"
        case rankChange = "rank_change"
        case cityName = "city_name"
    }

    public init(
        userId: UUID,
        username: String,
        displayName: String? = nil,
        avatarPreset: String = "default",
        totalKP: Int,
        rank: Int,
        cityRank: Int? = nil,
        isCurrentUser: Bool = false,
        rankChange: Int = 0,
        cityName: String? = nil
    ) {
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.avatarPreset = avatarPreset
        self.totalKP = totalKP
        self.rank = rank
        self.cityRank = cityRank
        self.isCurrentUser = isCurrentUser
        self.rankChange = rankChange
        self.cityName = cityName
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try c.decode(UUID.self, forKey: .userId)
        self.username = try c.decode(String.self, forKey: .username)
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        self.avatarPreset = try c.decodeIfPresent(String.self, forKey: .avatarPreset) ?? "default"
        self.totalKP = try c.decodeIfPresent(Int.self, forKey: .totalKP) ?? 0
        self.rank = try c.decode(Int.self, forKey: .rank)
        self.cityRank = try c.decodeIfPresent(Int.self, forKey: .cityRank)
        self.isCurrentUser = try c.decodeIfPresent(Bool.self, forKey: .isCurrentUser) ?? false
        self.rankChange = try c.decodeIfPresent(Int.self, forKey: .rankChange) ?? 0
        self.cityName = try c.decodeIfPresent(String.self, forKey: .cityName)
    }
}

public struct Challenge: Identifiable, Codable, Equatable {
    public let id: Int64
    public let type: String // "daily", "weekly", "community"
    public let title: String
    public let description: String?
    public let habitKey: String
    public let target: Double
    public let rewardKP: Int
    public let startAt: Date
    public let endAt: Date
    public let status: String
    public var progress: Double
    public var isJoined: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case description
        case habitKey = "habit_key"
        case target
        case rewardKP = "reward_kp"
        case startAt = "start_at"
        case endAt = "end_at"
        case status
        case progress
        case isJoined = "is_joined"
    }

    public init(
        id: Int64,
        type: String,
        title: String,
        description: String? = nil,
        habitKey: String,
        target: Double,
        rewardKP: Int = 50,
        startAt: Date,
        endAt: Date,
        status: String = "active",
        progress: Double = 0.0,
        isJoined: Bool = false
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.habitKey = habitKey
        self.target = target
        self.rewardKP = rewardKP
        self.startAt = startAt
        self.endAt = endAt
        self.status = status
        self.progress = progress
        self.isJoined = isJoined
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(Int64.self, forKey: .id)
        self.type = try c.decode(String.self, forKey: .type)
        self.title = try c.decode(String.self, forKey: .title)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.habitKey = try c.decode(String.self, forKey: .habitKey)
        self.target = try c.decode(Double.self, forKey: .target)
        self.rewardKP = try c.decodeIfPresent(Int.self, forKey: .rewardKP) ?? 50
        self.startAt = try c.decode(Date.self, forKey: .startAt)
        self.endAt = try c.decode(Date.self, forKey: .endAt)
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? "active"
        self.progress = try c.decodeIfPresent(Double.self, forKey: .progress) ?? 0.0
        self.isJoined = try c.decodeIfPresent(Bool.self, forKey: .isJoined) ?? false
    }

    public var progressPercent: Double {
        guard target > 0 else { return 0 }
        return min(progress / target, 1.0)
    }
}

public struct Achievement: Identifiable, Codable, Equatable {
    public let id: Int64
    public let key: String
    public let displayName: String
    public let description: String?
    public let category: String
    public let tier: String
    public let rewardKP: Int
    public var unlockedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case key
        case displayName = "display_name"
        case description
        case category
        case tier
        case rewardKP = "reward_kp"
        case unlockedAt = "unlocked_at"
    }

    public init(
        id: Int64,
        key: String,
        displayName: String,
        description: String? = nil,
        category: String = "general",
        tier: String = "bronze",
        rewardKP: Int = 50,
        unlockedAt: Date? = nil
    ) {
        self.id = id
        self.key = key
        self.displayName = displayName
        self.description = description
        self.category = category
        self.tier = tier
        self.rewardKP = rewardKP
        self.unlockedAt = unlockedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(Int64.self, forKey: .id)
        self.key = try c.decode(String.self, forKey: .key)
        self.displayName = try c.decode(String.self, forKey: .displayName)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.category = try c.decodeIfPresent(String.self, forKey: .category) ?? "milestone"
        let kp = try c.decodeIfPresent(Int.self, forKey: .rewardKP) ?? 50
        self.rewardKP = kp
        if let decodedTier = try c.decodeIfPresent(String.self, forKey: .tier) {
            self.tier = decodedTier
        } else {
            switch kp {
            case 500...: self.tier = "platinum"
            case 200..<500: self.tier = "gold"
            case 100..<200: self.tier = "silver"
            default: self.tier = "bronze"
            }
        }
        self.unlockedAt = try c.decodeIfPresent(Date.self, forKey: .unlockedAt)
    }

    public var isUnlocked: Bool {
        unlockedAt != nil
    }
}
