//
//  Habit.swift
//  klymb
//
//  Habit model matching seeded habits catalog.
//

import Foundation

public struct Habit: Identifiable, Codable, Equatable, Hashable {
    public let id: Int64
    public let key: String
    public let displayName: String
    public let unit: String
    public let dailyKPCap: Int
    public let manualKPCap: Int?
    public let manualAllowed: Bool
    public var isSelected: Bool

    public init(
        id: Int64,
        key: String,
        displayName: String,
        unit: String,
        dailyKPCap: Int,
        manualKPCap: Int? = nil,
        manualAllowed: Bool = false,
        isSelected: Bool = false
    ) {
        self.id = id
        self.key = key
        self.displayName = displayName
        self.unit = unit
        self.dailyKPCap = dailyKPCap
        self.manualKPCap = manualKPCap
        self.manualAllowed = manualAllowed
        self.isSelected = isSelected
    }

    public var iconName: String {
        switch key {
        case "steps": return "figure.walk"
        case "running": return "figure.run"
        case "walking_distance": return "figure.walk.motion"
        case "workout": return "dumbbell.fill"
        case "hydration": return "drop.fill"
        case "sleep": return "bed.double.fill"
        case "mindfulness": return "brain.head.profile"
        default: return "flame.fill"
        }
    }
}
