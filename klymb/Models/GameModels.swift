//
//  Activity.swift
//  klymb
//
//  Activity data model for local queuing & sync.
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
        kpEarned: Int? = nil
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
    }
}

public struct StreakInfo: Codable, Equatable {
    public let currentStreak: Int
    public let longestStreak: Int
    public let lastActiveDate: String?
    public let freezesRemaining: Int

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
    public let isCurrentUser: Bool

    public init(
        userId: UUID,
        username: String,
        displayName: String? = nil,
        avatarPreset: String = "default",
        totalKP: Int,
        rank: Int,
        cityRank: Int? = nil,
        isCurrentUser: Bool = false
    ) {
        self.userId = userId
        self.username = username
        self.displayName = displayName
        self.avatarPreset = avatarPreset
        self.totalKP = totalKP
        self.rank = rank
        self.cityRank = cityRank
        self.isCurrentUser = isCurrentUser
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

    public var isUnlocked: Bool {
        unlockedAt != nil
    }
}
