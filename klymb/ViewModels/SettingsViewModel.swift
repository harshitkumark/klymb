//
//  SettingsViewModel.swift
//  klymb
//
//  ViewModel managing profile editing, city changes with 30-day cooldown,
//  habit selection, GDPR data export, and account deletion (PRD §F15).
//  Follows AGENTS.md Rules 9, 13, 14, 15, 16.
//

import SwiftUI
import Combine

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var profile: Profile?
    @Published public var displayName: String = ""
    @Published public var selectedAvatarPreset: String = "default"

    // City & Cooldown
    @Published public var cities: [CityItem] = []
    @Published public var selectedCityId: Int64?
    @Published public var cityCooldown: CityChangeCooldown = CityChangeCooldown()

    // Habits
    @Published public var habits: [Habit] = []
    @Published public var selectedHabitIds: Set<Int64> = []

    // State & Feedback
    @Published public var isLoading: Bool = false
    @Published public var isSavingProfile: Bool = false
    @Published public var isSavingCity: Bool = false
    @Published public var isSavingHabits: Bool = false
    @Published public var isExportingData: Bool = false
    @Published public var errorMessage: String?
    @Published public var successMessage: String?

    // Privacy & Export
    @Published public var exportFile: UserDataExportFile?
    @Published public var showExportShareSheet: Bool = false
    @Published public var showDeleteAlert: Bool = false
    @Published public var isAccountDeleted: Bool = false

    private let container: AppContainerProtocol

    public init(container: AppContainerProtocol = AppContainer.mock) {
        self.container = container
    }

    public func loadSettings() async {
        isLoading = true
        errorMessage = nil
        do {
            async let profileTask = container.authService.getCurrentProfile()
            async let citiesTask = container.profileService.getCities()
            async let habitsTask = container.profileService.getHabits()
            async let cooldownTask = container.profileService.getCityCooldown()

            let (profile, cities, habits, cooldown) = try await (profileTask, citiesTask, habitsTask, cooldownTask)

            self.profile = profile
            self.displayName = profile?.displayName ?? ""
            self.selectedAvatarPreset = profile?.avatarPreset ?? "default"
            self.cities = cities
            self.selectedCityId = profile?.cityId
            self.cityCooldown = cooldown

            self.habits = habits
            self.selectedHabitIds = Set(habits.filter { $0.isSelected }.map { $0.id })
            self.isLoading = false
        } catch {
            self.errorMessage = "Failed to load settings. Please try again."
            self.isLoading = false
        }
    }

    // MARK: - Profile Editing

    public func saveProfile() async {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Display name cannot be empty."
            return
        }

        isSavingProfile = true
        errorMessage = nil
        do {
            let updated = try await container.profileService.updateProfile(
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                avatarPreset: selectedAvatarPreset
            )
            self.profile = updated
            self.isSavingProfile = false
            self.successMessage = "Profile updated successfully!"
            HapticManager.celebration()
        } catch {
            self.errorMessage = "Failed to update profile."
            self.isSavingProfile = false
        }
    }

    // MARK: - City Selection & 30-Day Cooldown

    public func changeCity(newCityId: Int64) async {
        guard newCityId != selectedCityId else { return }

        guard cityCooldown.canChangeCity else {
            self.errorMessage = "City changes are restricted to once every 30 days. Next change available in \(cityCooldown.cooldownDaysRemaining) days."
            HapticManager.buttonTap()
            return
        }

        isSavingCity = true
        errorMessage = nil
        do {
            try await container.profileService.setCity(cityId: newCityId)
            self.selectedCityId = newCityId
            self.cityCooldown = try await container.profileService.getCityCooldown()
            self.profile = try await container.authService.getCurrentProfile()
            self.isSavingCity = false
            self.successMessage = "City updated to \(profile?.cityName ?? "new city")! Leaderboards refreshed."
            HapticManager.celebration()
        } catch {
            self.errorMessage = "Failed to change city. Please try again later."
            self.isSavingCity = false
        }
    }

    // MARK: - Habit Selection (Enforcing Minimum 3)

    public func toggleHabit(id: Int64) {
        if selectedHabitIds.contains(id) {
            guard selectedHabitIds.count > 3 else {
                errorMessage = "At least 3 daily habits must be selected for competitive balance."
                HapticManager.buttonTap()
                return
            }
            selectedHabitIds.remove(id)
        } else {
            selectedHabitIds.insert(id)
        }
        HapticManager.selection()
    }

    public func saveHabits() async {
        guard selectedHabitIds.count >= 3 else {
            errorMessage = "Please select at least 3 habits before saving."
            return
        }

        isSavingHabits = true
        errorMessage = nil
        do {
            try await container.profileService.setUserHabits(habitIds: Array(selectedHabitIds))
            self.habits = try await container.profileService.getHabits()
            self.isSavingHabits = false
            self.successMessage = "Daily habits updated successfully!"
            HapticManager.celebration()
        } catch {
            self.errorMessage = "Failed to update daily habits."
            self.isSavingHabits = false
        }
    }

    // MARK: - GDPR Data Export

    public func exportData() async {
        isExportingData = true
        errorMessage = nil
        do {
            let jsonString = try await container.profileService.exportUserData()
            self.exportFile = UserDataExportFile(jsonString: jsonString)
            self.isExportingData = false
            self.showExportShareSheet = true
            HapticManager.celebration()
        } catch {
            self.errorMessage = "Failed to generate data export."
            self.isExportingData = false
        }
    }

    // MARK: - Account Deletion

    public func requestAccountDeletion() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await container.profileService.requestAccountDeletion()
            self.isAccountDeleted = true
            self.isLoading = false
            HapticManager.buttonTap()
        } catch {
            self.errorMessage = "Failed to request account deletion."
            self.isLoading = false
        }
    }
}
