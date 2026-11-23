//
//  ProfileViewModel.swift
//  klymb
//
//  ViewModel for Athlete Profile, Rank Progression, and Achievements Showcase
//  (PRD §F11 & AGENTS.md Rules 2, 15, 16).
//

import SwiftUI
import Combine

@MainActor
public final class ProfileViewModel: ObservableObject {
    @Published public var profile: Profile?
    @Published public var streak: StreakInfo = StreakInfo(currentStreak: 7, longestStreak: 14)
    @Published public var achievements: [Achievement] = []
    @Published public var userHabits: [Habit] = []
    @Published public var selectedFilter: AchievementCategoryFilter = .all
    @Published public var selectedAchievement: Achievement? = nil
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil

    private let profileService: ProfileServiceProtocol
    private let achievementService: AchievementServiceProtocol
    private let authService: AuthServiceProtocol

    public init(
        profileService: ProfileServiceProtocol,
        achievementService: AchievementServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.profileService = profileService
        self.achievementService = achievementService
        self.authService = authService
    }

    public init(container: AppContainerProtocol = AppContainer.mock) {
        self.profileService = container.profileService
        self.achievementService = container.achievementService
        self.authService = container.authService
    }

    // MARK: - Computed Properties

    public var totalKP: Int {
        profile?.totalKP ?? 1250
    }

    public var rankTier: RankTier {
        RankTier.tier(for: totalKP)
    }

    public var kpToNextTier: Int? {
        guard let next = rankTier.nextTierThreshold else { return nil }
        return max(0, next - totalKP)
    }

    public var tierProgressRatio: Double {
        guard let next = rankTier.nextTierThreshold else { return 1.0 }
        let prev = rankTier.previousTierThreshold
        let range = Double(next - prev)
        guard range > 0 else { return 1.0 }
        let current = Double(totalKP - prev)
        return min(1.0, max(0.0, current / range))
    }

    public var unlockedCount: Int {
        achievements.filter { $0.isUnlocked }.count
    }

    public var filteredAchievements: [Achievement] {
        switch selectedFilter {
        case .all:
            return achievements
        case .milestone:
            return achievements.filter { $0.category.lowercased() == "milestone" }
        case .streak:
            return achievements.filter { $0.category.lowercased() == "streak" }
        case .distance:
            return achievements.filter { $0.category.lowercased() == "distance" }
        case .competition:
            return achievements.filter { $0.category.lowercased() == "competition" }
        }
    }

    // MARK: - Actions

    public func loadProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            async let fetchedProfile = authService.getCurrentProfile()
            async let fetchedStreak = profileService.getStreak()
            async let fetchedAchievements = achievementService.getAchievements()
            async let fetchedHabits = profileService.getUserHabits()

            let (p, s, a, h) = try await (fetchedProfile, fetchedStreak, fetchedAchievements, fetchedHabits)
            self.profile = p ?? Profile(
                id: UUID(),
                username: "champion_dev",
                displayName: "Champion Dev",
                avatarPreset: "star",
                cityName: "San Francisco",
                totalKP: 1250
            )
            self.streak = s
            self.achievements = a
            self.userHabits = h
            self.isLoading = false
        } catch {
            self.errorMessage = "Unable to load profile. Pull down to refresh."
            self.isLoading = false
        }
    }

    public func setFilter(_ filter: AchievementCategoryFilter) {
        guard filter != selectedFilter else { return }
        selectedFilter = filter
        HapticManager.selection()
    }

    public func selectAchievement(_ achievement: Achievement) {
        selectedAchievement = achievement
        HapticManager.selection()
    }

    public func dismissAchievementDetail() {
        selectedAchievement = nil
    }
}
