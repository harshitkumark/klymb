//
//  LogModels.swift
//  klymb
//
//  Models and configurations for manual activity logging (PRD §F6 & KP Rules).
//  (AGENTS.md Rule 2 & 3: Server authoritative, estimates labeled).
//

import Foundation

public enum ManualLogType: String, CaseIterable, Identifiable {
    case hydration = "hydration"
    case workout = "workout"
    case mindfulness = "mindfulness"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hydration: return "Hydration"
        case .workout: return "Workout"
        case .mindfulness: return "Mindfulness"
        }
    }

    public var habitId: Int64 {
        switch self {
        case .workout: return 4
        case .hydration: return 5
        case .mindfulness: return 7
        }
    }

    public var unit: String {
        switch self {
        case .hydration: return "ml"
        case .workout, .mindfulness: return "minutes"
        }
    }

    public var iconName: String {
        switch self {
        case .hydration: return "drop.fill"
        case .workout: return "dumbbell.fill"
        case .mindfulness: return "brain.head.profile"
        }
    }

    public var manualDailyKPCap: Int {
        switch self {
        case .hydration: return 20
        case .workout: return 40
        case .mindfulness: return 15
        }
    }

    public var quickPresets: [Double] {
        switch self {
        case .hydration: return [250, 500, 750, 1000]
        case .workout: return [15, 30, 45, 60]
        case .mindfulness: return [5, 10, 15, 20]
        }
    }

    public var stepAmount: Double {
        switch self {
        case .hydration: return 50
        case .workout, .mindfulness: return 5
        }
    }

    public var maxManualValue: Double {
        switch self {
        case .hydration: return 3000
        case .workout: return 180
        case .mindfulness: return 90
        }
    }

    /// Provides UX estimate labeled as non-authoritative (Rule 2 & 3)
    public func estimateKP(for quantity: Double) -> Int {
        switch self {
        case .hydration:
            // ~1 KP per 250ml up to daily manual cap
            let calculated = Int(quantity / 250.0)
            return min(manualDailyKPCap, calculated)
        case .workout:
            // ~0.8 KP per minute up to daily manual cap
            let calculated = Int(quantity * 0.8)
            return min(manualDailyKPCap, calculated)
        case .mindfulness:
            // ~0.75 KP per minute up to daily manual cap
            let calculated = Int(quantity * 0.75)
            return min(manualDailyKPCap, calculated)
        }
    }
}

public struct WorkoutTypeOption: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let iconName: String

    public init(id: String, name: String, iconName: String) {
        self.id = id
        self.name = name
        self.iconName = iconName
    }

    public static let allOptions: [WorkoutTypeOption] = [
        WorkoutTypeOption(id: "strength", name: "Strength", iconName: "figure.strengthtraining.traditional"),
        WorkoutTypeOption(id: "hiit", name: "HIIT", iconName: "bolt.heart.fill"),
        WorkoutTypeOption(id: "cardio", name: "Cardio", iconName: "figure.run"),
        WorkoutTypeOption(id: "yoga", name: "Yoga", iconName: "figure.mind.and.body"),
        WorkoutTypeOption(id: "boxing", name: "Boxing", iconName: "figure.boxing"),
        WorkoutTypeOption(id: "other", name: "Other", iconName: "figure.cooldown")
    ]
}
