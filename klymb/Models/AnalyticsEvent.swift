//
//  AnalyticsEvent.swift
//  klymb
//
//  Privacy-first analytics event schema (PRD §F18 & Architecture §8.4).
//  Follows AGENTS.md Rule 17: Strictly ZERO HealthKit or biometric data in analytics.
//

import Foundation

public enum AnalyticsEvent: Equatable, Sendable {
    case screenView(name: String)
    case tabSwitched(to: String)
    case authCompleted(provider: String)
    case onboardingStepCompleted(step: Int)
    case challengeJoined(id: UUID)
    case challengeLeft(id: UUID)
    case friendCheered(friendId: UUID)
    case friendRequestSent(targetId: UUID)
    case manualLogSubmitted(category: String)
    case cityChanged(cityId: Int64)
    case notificationToggled(type: String, enabled: Bool)
    case networkStateChanged(isConnected: Bool)

    public var name: String {
        switch self {
        case .screenView: return "screen_view"
        case .tabSwitched: return "tab_switched"
        case .authCompleted: return "auth_completed"
        case .onboardingStepCompleted: return "onboarding_step_completed"
        case .challengeJoined: return "challenge_joined"
        case .challengeLeft: return "challenge_left"
        case .friendCheered: return "friend_cheered"
        case .friendRequestSent: return "friend_request_sent"
        case .manualLogSubmitted: return "manual_log_submitted"
        case .cityChanged: return "city_changed"
        case .notificationToggled: return "notification_toggled"
        case .networkStateChanged: return "network_state_changed"
        }
    }

    public var parameters: [String: Any] {
        var params: [String: Any] = [:]
        switch self {
        case .screenView(let name):
            params["screen_name"] = name
        case .tabSwitched(let tab):
            params["tab_name"] = tab
        case .authCompleted(let provider):
            params["auth_provider"] = provider
        case .onboardingStepCompleted(let step):
            params["step_number"] = step
        case .challengeJoined(let id):
            params["challenge_id"] = id.uuidString
        case .challengeLeft(let id):
            params["challenge_id"] = id.uuidString
        case .friendCheered(let friendId):
            params["friend_id"] = friendId.uuidString
        case .friendRequestSent(let targetId):
            params["target_id"] = targetId.uuidString
        case .manualLogSubmitted(let category):
            // Category tag only — no raw quantities or metrics
            params["category"] = category
        case .cityChanged(let cityId):
            params["city_id"] = cityId
        case .notificationToggled(let type, let enabled):
            params["type"] = type
            params["enabled"] = enabled
        case .networkStateChanged(let isConnected):
            params["is_connected"] = isConnected
        }

        #if DEBUG
        // Rule 17 Assertion: Verify no forbidden health metric leaks into analytics
        let forbidden = ["step", "heart", "hr", "calorie", "distance", "workout_duration", "sleep_hours"]
        for key in params.keys {
            for term in forbidden {
                assert(!key.lowercased().contains(term), "AGENTS.md Rule 17 Violation: Health metric leak in analytics key: \(key)")
            }
        }
        #endif

        return params
    }
}
