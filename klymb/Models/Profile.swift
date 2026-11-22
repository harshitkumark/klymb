//
//  Profile.swift
//  klymb
//
//  User profile model.
//

import Foundation

public struct Profile: Identifiable, Codable, Equatable {
    public let id: UUID
    public var username: String
    public var displayName: String?
    public var avatarPreset: String
    public var cityId: Int64?
    public var cityName: String?
    public var totalKP: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        username: String,
        displayName: String? = nil,
        avatarPreset: String = "default",
        cityId: Int64? = nil,
        cityName: String? = nil,
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
        self.totalKP = totalKP
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var title: String {
        displayName ?? "@\(username)"
    }
}
