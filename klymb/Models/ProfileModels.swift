//
//  ProfileModels.swift
//  klymb
//
//  Display models, rank tiers, and achievement formatting for the Profile screen (PRD §F11 & Design System §9.9).
//

import SwiftUI

public enum RankTier: String, CaseIterable, Identifiable {
    case bronze = "Bronze Athlete"
    case silver = "Silver Competitor"
    case gold = "Gold Champion"
    case platinum = "Platinum Elite"
    case diamond = "Diamond Legend"

    public var id: String { rawValue }

    public static func tier(for totalKP: Int) -> RankTier {
        switch totalKP {
        case 0..<1000: return .bronze
        case 1000..<2500: return .silver
        case 2500..<5000: return .gold
        case 5000..<10000: return .platinum
        default: return .diamond
        }
    }

    public var tierColor: Color {
        switch self {
        case .bronze: return Color.KlymbRank.bronze
        case .silver: return Color.KlymbRank.silver
        case .gold: return Color.KlymbRank.gold
        case .platinum: return Color.KlymbAccent.primary
        case .diamond: return Color.KlymbAccent.soft
        }
    }

    public var iconName: String {
        switch self {
        case .bronze: return "shield.fill"
        case .silver: return "shield.lefthalf.filled"
        case .gold: return "crown.fill"
        case .platinum: return "bolt.shield.fill"
        case .diamond: return "sparkles"
        }
    }

    public var nextTierThreshold: Int? {
        switch self {
        case .bronze: return 1000
        case .silver: return 2500
        case .gold: return 5000
        case .platinum: return 10000
        case .diamond: return nil
        }
    }

    public var previousTierThreshold: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 1000
        case .gold: return 2500
        case .platinum: return 5000
        case .diamond: return 10000
        }
    }
}

public enum AchievementCategoryFilter: String, CaseIterable, Identifiable, Equatable {
    case all = "All"
    case milestone = "Milestones"
    case streak = "Streaks"
    case distance = "Distance"
    case competition = "Competitive"

    public var id: String { rawValue }
    public var title: String { rawValue }
}

public extension Achievement {
    var tierColor: Color {
        switch tier.lowercased() {
        case "bronze": return Color.KlymbRank.bronze
        case "silver": return Color.KlymbRank.silver
        case "gold": return Color.KlymbRank.gold
        case "platinum", "diamond": return Color.KlymbAccent.soft
        default: return ColorTokens.textTertiary
        }
    }

    var iconName: String {
        switch key {
        case "first_steps": return "shoeprints.fill"
        case "week_warrior", "month_master", "streak_7", "streak_30": return "flame.fill"
        case "century_club": return "crown.fill"
        case "step_legend": return "figure.walk"
        case "century_run", "marathoner": return "figure.run"
        case "hydro_pro": return "drop.fill"
        case "zen_master": return "sparkles"
        case "podium_finish", "first_place", "challenge_champion": return "trophy.fill"
        case "city_star", "city_champion": return "star.fill"
        case "social_butterfly": return "person.3.fill"
        case "century_ride": return "figure.outdoor.cycle"
        default:
            switch category.lowercased() {
            case "streak": return "flame.fill"
            case "distance", "habit": return "figure.walk"
            case "competition", "challenge": return "trophy.fill"
            case "leaderboard": return "star.fill"
            case "social": return "person.3.fill"
            default: return "star.fill"
            }
        }
    }
}
