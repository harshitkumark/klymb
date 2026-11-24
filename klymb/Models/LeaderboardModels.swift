//
//  LeaderboardModels.swift
//  klymb
//
//  Scopes, periods, and presentation models for Leaderboards (PRD §F10 & Design System §9.7).
//

import SwiftUI

public enum LeaderboardScope: String, CaseIterable, Identifiable {
    case city = "city"
    case global = "global"
    case friends = "friends"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .city: return "City"
        case .global: return "Global"
        case .friends: return "Friends"
        }
    }

    public var iconName: String {
        switch self {
        case .city: return "building.2.fill"
        case .global: return "globe.americas.fill"
        case .friends: return "person.2.fill"
        }
    }
}

public enum LeaderboardPeriod: String, CaseIterable, Identifiable {
    case daily = "daily"
    case weekly = "weekly"
    case allTime = "alltime"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .allTime: return "All-Time"
        }
    }
}

public extension LeaderboardEntry {
    var titleDisplay: String {
        displayName ?? "@\(username)"
    }

    var avatarIconName: String {
        switch avatarPreset {
        case "sprinter": return "flame.fill"
        case "climber": return "figure.climbing"
        case "cyclist": return "figure.outdoor.cycle"
        case "zen": return "figure.mind.and.body"
        case "star": return "star.fill"
        case "bolt": return "bolt.fill"
        case "shield": return "shield.fill"
        default: return "figure.run"
        }
    }

    var rankColor: Color {
        switch rank {
        case 1: return Color.KlymbRank.gold
        case 2: return Color.KlymbRank.silver
        case 3: return Color.KlymbRank.bronze
        case 4...10: return ColorTokens.electricCyan
        default: return ColorTokens.textTertiary
        }
    }
}
