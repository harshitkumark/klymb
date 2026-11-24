//
//  NotificationModels.swift
//  klymb
//
//  Notification payload models, user preference toggles, and deep link routing (PRD §F14 & Backend B14).
//

import Foundation

public struct NotificationPreferences: Codable, Equatable {
    public var overtaken: Bool
    public var challengeEnding: Bool
    public var streakRisk: Bool

    enum CodingKeys: String, CodingKey {
        case overtaken
        case challengeEnding = "challenge_ending"
        case streakRisk = "streak_risk"
    }

    public init(
        overtaken: Bool = true,
        challengeEnding: Bool = true,
        streakRisk: Bool = true
    ) {
        self.overtaken = overtaken
        self.challengeEnding = challengeEnding
        self.streakRisk = streakRisk
    }
}

public enum NotificationType: String, Codable {
    case overtaken = "overtaken"
    case overtake = "overtake" // legacy alias for simulated alert compatibility
    case streakRisk = "streak_risk"
    case challengeEnding = "challenge_ending"
    case achievement = "achievement"
    case friendRequest = "friend_request"
    case teamInvite = "team_invite"
    case cheer = "cheer"
    case general = "general"

    public var targetTab: MainTab {
        switch self {
        case .overtaken, .overtake: return .compete
        case .streakRisk: return .home
        case .challengeEnding: return .challenges
        case .achievement: return .profile
        case .friendRequest, .teamInvite, .cheer: return .compete
        case .general: return .home
        }
    }
}

public struct AppNotificationPayload: Equatable {
    public let type: NotificationType
    public let title: String
    public let body: String
    public let targetTab: MainTab
    public let entityId: String?

    public init(
        type: NotificationType,
        title: String,
        body: String,
        targetTab: MainTab,
        entityId: String? = nil
    ) {
        self.type = type
        self.title = title
        self.body = body
        self.targetTab = targetTab
        self.entityId = entityId
    }

    public static func parse(from userInfo: [AnyHashable: Any]) -> AppNotificationPayload? {
        guard let typeString = userInfo["type"] as? String,
              let type = NotificationType(rawValue: typeString) else {
            return nil
        }

        let title = (userInfo["aps"] as? [String: Any])?["alert"] as? String ?? (userInfo["title"] as? String) ?? "Klymb"
        let body = (userInfo["body"] as? String) ?? ""
        let entityId = userInfo["entity_id"] as? String

        return AppNotificationPayload(
            type: type,
            title: title,
            body: body,
            targetTab: type.targetTab,
            entityId: entityId
        )
    }
}
