//
//  SettingsModels.swift
//  klymb
//
//  Models for Settings, City change cooldown, Avatar presets,
//  and GDPR/Privacy export and deletion (PRD §F15 & Backend b4, b16).
//  Follows AGENTS.md Rules 9, 13, 14.
//

import SwiftUI

// MARK: - City Change Cooldown
public struct CityChangeCooldown: Equatable, Sendable {
    public let lastChangedAt: Date?
    public let canChangeCity: Bool
    public let cooldownDaysRemaining: Int
    public let nextEligibleDate: Date?

    public init(
        lastChangedAt: Date? = nil,
        cooldownDays: Int = 30
    ) {
        self.lastChangedAt = lastChangedAt
        guard let lastChanged = lastChangedAt else {
            self.canChangeCity = true
            self.cooldownDaysRemaining = 0
            self.nextEligibleDate = nil
            return
        }

        let calendar = Calendar.current
        if let eligible = calendar.date(byAdding: .day, value: cooldownDays, to: lastChanged) {
            self.nextEligibleDate = eligible
            let now = Date()
            if now >= eligible {
                self.canChangeCity = true
                self.cooldownDaysRemaining = 0
            } else {
                self.canChangeCity = false
                let components = calendar.dateComponents([.day, .hour], from: now, to: eligible)
                self.cooldownDaysRemaining = max(1, components.day ?? 1)
            }
        } else {
            self.canChangeCity = true
            self.cooldownDaysRemaining = 0
            self.nextEligibleDate = nil
        }
    }
}

// MARK: - Avatar Preset Option
public struct AvatarPreset: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let iconName: String
    public let colorName: String

    public init(id: String, displayName: String, iconName: String, colorName: String) {
        self.id = id
        self.displayName = displayName
        self.iconName = iconName
        self.colorName = colorName
    }

    public static let availablePresets: [AvatarPreset] = [
        AvatarPreset(id: "default", displayName: "Contender", iconName: "person.crop.circle.fill", colorName: "electricCyan"),
        AvatarPreset(id: "bolt", displayName: "Thunderbolt", iconName: "bolt.shield.fill", colorName: "neonGreen"),
        AvatarPreset(id: "flame", displayName: "Inferno", iconName: "flame.circle.fill", colorName: "neonOrange"),
        AvatarPreset(id: "crown", displayName: "Monarch", iconName: "crown.fill", colorName: "gold"),
        AvatarPreset(id: "figure.run", displayName: "Velocity", iconName: "figure.run.circle.fill", colorName: "electricCyan"),
        AvatarPreset(id: "shield", displayName: "Titan", iconName: "shield.checkered", colorName: "cyberPurple"),
        AvatarPreset(id: "heart", displayName: "Vigor", iconName: "heart.circle.fill", colorName: "neonRed"),
        AvatarPreset(id: "star", displayName: "Astral", iconName: "star.circle.fill", colorName: "gold")
    ]
}

// MARK: - Account Deletion Info
public struct AccountDeletionInfo: Codable, Equatable, Sendable {
    public let scheduledFor: Date
    public let gracePeriodDays: Int

    public init(
        scheduledFor: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
        gracePeriodDays: Int = 30
    ) {
        self.scheduledFor = scheduledFor
        self.gracePeriodDays = gracePeriodDays
    }
}

// MARK: - User Data Export Document
public struct UserDataExportFile: Identifiable {
    public let id = UUID()
    public let jsonString: String
    public let exportedAt: Date

    public init(jsonString: String, exportedAt: Date = Date()) {
        self.jsonString = jsonString
        self.exportedAt = exportedAt
    }
}
