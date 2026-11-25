//
//  ChallengeModels.swift
//  klymb
//
//  Filters, presentation models, and display formatting for Challenges (PRD §F12).
//

import SwiftUI

public enum ChallengeCategoryFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case daily = "daily"
    case weekly = "weekly"
    case community = "community"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: return "All"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .community: return "Community"
        }
    }

    public var iconName: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar"
        case .community: return "person.3.fill"
        }
    }
}

public extension Challenge {
    var progressRatio: Double {
        guard target > 0 else { return 0.0 }
        return min(1.0, max(0.0, progress / target))
    }

    var isCompleted: Bool {
        progress >= target
    }

    var habitIconName: String {
        switch habitKey {
        case "steps": return "figure.walk"
        case "running": return "figure.run"
        case "walking_distance": return "figure.walk.motion"
        case "workout": return "dumbbell.fill"
        case "hydration", "water": return "drop.fill"
        case "mindfulness": return "sparkles"
        case "sleep": return "bed.double.fill"
        default: return "flag.fill"
        }
    }

    var categoryColor: Color {
        switch type {
        case "daily": return ColorTokens.terracotta
        case "weekly": return ColorTokens.softCopper
        case "community": return ColorTokens.neonYellow
        default: return ColorTokens.terracotta
        }
    }

    var formattedTarget: String {
        switch habitKey {
        case "steps":
            return "\(Int(target).formatted()) steps"
        case "running", "walking_distance":
            return target.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(target)) km" : String(format: "%.1f km", target)
        case "hydration", "water":
            return "\(Int(target).formatted()) ml"
        case "mindfulness", "workout":
            return "\(Int(target)) min"
        case "sleep":
            return String(format: "%.1f hrs", target)
        default:
            return "\(Int(target)) units"
        }
    }

    var formattedCurrent: String {
        switch habitKey {
        case "steps":
            return "\(Int(progress).formatted())"
        case "running", "walking_distance":
            return progress.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(progress))" : String(format: "%.1f", progress)
        case "hydration", "water":
            return "\(Int(progress).formatted())"
        case "mindfulness", "workout":
            return "\(Int(progress))"
        case "sleep":
            return String(format: "%.1f", progress)
        default:
            return "\(Int(progress))"
        }
    }

    var timeRemainingText: String {
        let now = Date()
        guard endAt > now else { return "Ended" }
        let interval = endAt.timeIntervalSince(now)

        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if days > 0 {
            return "\(days)d \(hours)h left"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else {
            return "\(max(1, minutes))m left"
        }
    }
}
