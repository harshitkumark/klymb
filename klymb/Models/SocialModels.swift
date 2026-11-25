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

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarPreset = "avatar_preset"
        case cityName = "city_name"
        case totalKP = "total_kp"
        case status
        case streak
    }

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

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.username = try c.decode(String.self, forKey: .username)
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        self.avatarPreset = try c.decodeIfPresent(String.self, forKey: .avatarPreset) ?? "default"
        self.cityName = try c.decodeIfPresent(String.self, forKey: .cityName)
        self.totalKP = try c.decodeIfPresent(Int.self, forKey: .totalKP) ?? 0
        self.status = try c.decodeIfPresent(FriendshipStatus.self, forKey: .status) ?? .none
        self.streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
    }

    public var titleDisplay: String {
        displayName ?? "@\(username)"
    }

    public var avatarIconName: String {
        KlymbIconCatalog.avatarIcon(for: avatarPreset)
    }

    public var rankTier: RankTier {
        RankTier.tier(for: totalKP)
    }
}
