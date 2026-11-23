//
//  HomeModels.swift
//  klymb
//
//  Data models for Home dashboard: daily habit progress and leaderboard overtake nudges.
//  (PRD §F20 & Design System §8.1).
//

import Foundation

public struct DailyHabitProgress: Identifiable, Equatable {
    public let id: Int64
    public let key: String
    public let displayName: String
    public let iconName: String
    public let currentQuantity: Double
    public let targetQuantity: Double
    public let unit: String
    public let kpEarnedToday: Int
    public let dailyKPCap: Int

    public init(
        id: Int64,
        key: String,
        displayName: String,
        iconName: String,
        currentQuantity: Double,
        targetQuantity: Double,
        unit: String,
        kpEarnedToday: Int,
        dailyKPCap: Int
    ) {
        self.id = id
        self.key = key
        self.displayName = displayName
        self.iconName = iconName
        self.currentQuantity = currentQuantity
        self.targetQuantity = targetQuantity
        self.unit = unit
        self.kpEarnedToday = kpEarnedToday
        self.dailyKPCap = dailyKPCap
    }

    public var isCompleted: Bool {
        currentQuantity >= targetQuantity
    }

    public var progress: Double {
        guard targetQuantity > 0 else { return 0 }
        return min(1.0, currentQuantity / targetQuantity)
    }

    public var formattedCurrentQuantity: String {
        if unit == "count" {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: Int(currentQuantity))) ?? "\(Int(currentQuantity))"
        } else if unit == "ml" {
            return "\(Int(currentQuantity)) ml"
        } else if unit == "minutes" {
            return "\(Int(currentQuantity)) min"
        } else if unit == "hours" {
            return String(format: "%.1fh", currentQuantity)
        } else {
            return String(format: "%.1f %@", currentQuantity, unit)
        }
    }

    public var formattedTargetQuantity: String {
        if unit == "count" {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: Int(targetQuantity))) ?? "\(Int(targetQuantity))"
        } else if unit == "ml" {
            return "\(Int(targetQuantity)) ml"
        } else if unit == "minutes" {
            return "\(Int(targetQuantity)) min"
        } else if unit == "hours" {
            return String(format: "%.0fh", targetQuantity)
        } else {
            return String(format: "%.1f %@", targetQuantity, unit)
        }
    }
}

public struct LeaderboardOvertakeNudge: Equatable {
    public let cityName: String
    public let currentRank: Int
    public let rankChange: Int // e.g. +3 or -1
    public let targetRivalUsername: String
    public let kpNeededToOvertake: Int

    public init(
        cityName: String,
        currentRank: Int,
        rankChange: Int,
        targetRivalUsername: String,
        kpNeededToOvertake: Int
    ) {
        self.cityName = cityName
        self.currentRank = currentRank
        self.rankChange = rankChange
        self.targetRivalUsername = targetRivalUsername
        self.kpNeededToOvertake = kpNeededToOvertake
    }
}
