//
//  AppContainer.swift
//  klymb
//
//  Dependency Injection container (AGENTS.md Rule 16).
//

import Foundation

public protocol AppContainerProtocol {
    var authService: AuthServiceProtocol { get }
    var profileService: ProfileServiceProtocol { get }
    var healthKitService: HealthKitServiceProtocol { get }
    var syncService: SyncServiceProtocol { get }
    var activityService: ActivityServiceProtocol { get }
    var leaderboardService: LeaderboardServiceProtocol { get }
    var challengeService: ChallengeServiceProtocol { get }
    var achievementService: AchievementServiceProtocol { get }
    var socialService: SocialServiceProtocol { get }
    var notificationService: NotificationServiceProtocol { get }
}

public final class AppContainer: AppContainerProtocol {
    public let authService: AuthServiceProtocol
    public let profileService: ProfileServiceProtocol
    public let healthKitService: HealthKitServiceProtocol
    public let syncService: SyncServiceProtocol
    public let activityService: ActivityServiceProtocol
    public let leaderboardService: LeaderboardServiceProtocol
    public let challengeService: ChallengeServiceProtocol
    public let achievementService: AchievementServiceProtocol
    public let socialService: SocialServiceProtocol
    public let notificationService: NotificationServiceProtocol

    public init(
        authService: AuthServiceProtocol = MockAuthService(),
        profileService: ProfileServiceProtocol = MockProfileService(),
        healthKitService: HealthKitServiceProtocol = MockHealthKitService(),
        syncService: SyncServiceProtocol = MockSyncService(),
        activityService: ActivityServiceProtocol = MockActivityService(),
        leaderboardService: LeaderboardServiceProtocol = MockLeaderboardService(),
        challengeService: ChallengeServiceProtocol = MockChallengeService(),
        achievementService: AchievementServiceProtocol = MockAchievementService(),
        socialService: SocialServiceProtocol = MockSocialService(),
        notificationService: NotificationServiceProtocol = MockNotificationService()
    ) {
        self.authService = authService
        self.profileService = profileService
        self.healthKitService = healthKitService
        self.syncService = syncService
        self.activityService = activityService
        self.leaderboardService = leaderboardService
        self.challengeService = challengeService
        self.achievementService = achievementService
        self.socialService = socialService
        self.notificationService = notificationService
    }

    /// Convenience preview/mock container
    public static var mock: AppContainer {
        AppContainer()
    }

    /// Production container wired with real device services
    public static var live: AppContainer {
        let healthKit = HealthKitService()
        let profile = MockProfileService()
        let activity = MockActivityService()
        return AppContainer(
            profileService: profile,
            healthKitService: healthKit,
            syncService: ActivitySyncService(
                healthKitService: healthKit,
                activityService: activity,
                profileService: profile
            ),
            activityService: activity
        )
    }
}
