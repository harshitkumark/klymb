//
//  Habit.swift
//  klymb
//
//  Habit model matching seeded habits catalog & get_my_habits() RPC.
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

    enum CodingKeys: String, CodingKey {
        case id
        case key
        case displayName = "display_name"
        case unit
        case dailyKPCap = "daily_kp_cap"
        case manualKPCap = "manual_kp_cap"
        case manualAllowed = "manual_allowed"
        case isSelected = "is_selected"
    }

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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(Int64.self, forKey: .id)
        self.key = try c.decode(String.self, forKey: .key)
        self.displayName = try c.decode(String.self, forKey: .displayName)
        self.unit = try c.decode(String.self, forKey: .unit)
        self.dailyKPCap = try c.decode(Int.self, forKey: .dailyKPCap)
        self.manualKPCap = try c.decodeIfPresent(Int.self, forKey: .manualKPCap)
        self.manualAllowed = try c.decodeIfPresent(Bool.self, forKey: .manualAllowed) ?? false
        self.isSelected = try c.decodeIfPresent(Bool.self, forKey: .isSelected) ?? false
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
