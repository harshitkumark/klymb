//
//  Profile.swift
//  klymb
//
//  User profile model matching public.profiles + get_my_profile() RPC.
//

import Foundation

public struct Profile: Identifiable, Codable, Equatable {
    public let id: UUID
    public var username: String
    public var displayName: String?
    public var avatarPreset: String
    public var cityId: Int64?
    public var cityName: String?
    public var cityChangedAt: Date?
    public var totalKP: Int
    public var createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarPreset = "avatar_preset"
        case cityId = "city_id"
        case cityName = "city_name"
        case cityChangedAt = "city_changed_at"
        case totalKP = "total_kp"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: UUID,
        username: String,
        displayName: String? = nil,
        avatarPreset: String = "default",
        cityId: Int64? = nil,
        cityName: String? = nil,
        cityChangedAt: Date? = nil,
        totalKP: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarPreset = avatarPreset
        self.cityId = cityId
        self.cityName = cityName
        self.cityChangedAt = cityChangedAt
        self.totalKP = totalKP
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.username = try c.decode(String.self, forKey: .username)
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        self.avatarPreset = try c.decodeIfPresent(String.self, forKey: .avatarPreset) ?? "default"
        self.cityId = try c.decodeIfPresent(Int64.self, forKey: .cityId)
        self.cityName = try c.decodeIfPresent(String.self, forKey: .cityName)
        self.cityChangedAt = try c.decodeIfPresent(Date.self, forKey: .cityChangedAt)
        self.totalKP = try c.decodeIfPresent(Int.self, forKey: .totalKP) ?? 0
        self.createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    public var title: String {
        displayName ?? "@\(username)"
    }
}
