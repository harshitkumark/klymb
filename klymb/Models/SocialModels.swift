//
//  SocialModels.swift
//  klymb
//
//  Social & Friendship models, search items, and status representations (PRD §F11 & Backend B11).
//

import SwiftUI

public enum FriendshipStatus: String, Codable, Equatable {
    case none
    case pendingSent = "pending_sent"
    case pendingReceived = "pending_received"
    case friends
}

public struct FriendItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let username: String
    public let displayName: String?
    public let avatarPreset: String
    public let cityName: String?
    public let totalKP: Int
    public var status: FriendshipStatus
    public let streak: Int

    public init(
        id: UUID,
        username: String,
        displayName: String? = nil,
        avatarPreset: String = "runner",
        cityName: String? = nil,
        totalKP: Int = 0,
        status: FriendshipStatus = .friends,
        streak: Int = 0
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarPreset = avatarPreset
        self.cityName = cityName
        self.totalKP = totalKP
        self.status = status
        self.streak = streak
    }

    public var titleDisplay: String {
        displayName ?? "@\(username)"
    }

    public var avatarIconName: String {
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

    public var rankTier: RankTier {
        RankTier.tier(for: totalKP)
    }
}
