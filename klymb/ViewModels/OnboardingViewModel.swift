//
//  OnboardingViewModel.swift
//  klymb
//
//  ViewModel coordinating the multi-step onboarding journey (PRD §F21).
//  (AGENTS.md Rule 15: SwiftUI + MVVM, Rule 16: Protocol DI).
//

import SwiftUI
import Combine

public enum OnboardingStep: Int, CaseIterable, Comparable {
    case username = 0
    case avatar = 1
    case city = 2
    case habits = 3
    case permissions = 4
    case summary = 5

    public static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var title: String {
        switch self {
        case .username: return "Identity"
        case .avatar: return "Avatar"
        case .city: return "Arena"
        case .habits: return "Habits"
        case .permissions: return "Permissions"
        case .summary: return "Ready"
        }
    }

    public var stepNumber: Int {
        rawValue + 1
    }
}

public struct AvatarPresetOption: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let iconName: String
    public let description: String

    public init(id: String, title: String, iconName: String, description: String) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.description = description
    }
}

@MainActor
public final class OnboardingViewModel: ObservableObject {
    // MARK: - Published Step State
    @Published public var currentStep: OnboardingStep = .username
    @Published public var isLoading: Bool = false
    @Published public var isSubmitting: Bool = false
    @Published public var errorMessage: String?
    @Published public var showError: Bool = false

    // MARK: - Step 1: Identity
    @Published public var username: String = "" {
        didSet {
            validateUsername()
        }
    }
    @Published public var displayName: String = ""
    @Published public var usernameValidationMessage: String?
    @Published public var isUsernameValid: Bool = false

    // MARK: - Step 2: Avatar
    @Published public var selectedAvatar: String = "default"
    public let avatarPresets: [AvatarPresetOption] = [
        AvatarPresetOption(id: "default", title: "Apex", iconName: "figure.run", description: "All-round athlete"),
        AvatarPresetOption(id: "sprinter", title: "Blaze", iconName: "flame.fill", description: "Speed & intensity"),
        AvatarPresetOption(id: "climber", title: "Summit", iconName: "figure.climbing", description: "Endurance & vertical"),
        AvatarPresetOption(id: "cyclist", title: "Velocity", iconName: "figure.outdoor.cycle", description: "Distance pursuer"),
        AvatarPresetOption(id: "zen", title: "Zen", iconName: "figure.mind.and.body", description: "Mindful balance"),
        AvatarPresetOption(id: "star", title: "Titan", iconName: "star.fill", description: "Competitive elite"),
        AvatarPresetOption(id: "bolt", title: "Thunder", iconName: "bolt.fill", description: "High-voltage energy"),
        AvatarPresetOption(id: "shield", title: "Guardian", iconName: "shield.fill", description: "Consistency & armor")
    ]

    // MARK: - Step 3: City
    @Published public var cities: [CityItem] = []
    @Published public var citySearchQuery: String = ""
    @Published public var selectedCity: CityItem?

    // MARK: - Step 4: Habits
    @Published public var habits: [Habit] = []
    @Published public var selectedHabitIds: Set<Int64> = []

    // MARK: - Step 5: Permissions
    @Published public var healthKitRequested: Bool = false
    @Published public var notificationsRequested: Bool = false

    // MARK: - Dependencies
    private let profileService: ProfileServiceProtocol
    private let authService: AuthServiceProtocol
    private let healthKitService: HealthKitServiceProtocol
    private let syncService: SyncServiceProtocol

    private let reservedUsernames: Set<String> = [
        "admin", "administrator", "klymb", "support", "help",
        "official", "moderator", "root", "system", "superuser",
        "security", "team", "modguy", "chiefadmin"
    ]

    public init(container: AppContainerProtocol = AppContainer.mock) {
        self.profileService = container.profileService
        self.authService = container.authService
        self.healthKitService = container.healthKitService
        self.syncService = container.syncService
        loadInitialData()
    }

    // MARK: - Data Loading
    public func loadInitialData() {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                async let fetchedCities = profileService.getCities()
                async let fetchedHabits = profileService.getHabits()

                let (loadedCities, loadedHabits) = try await (fetchedCities, fetchedHabits)
                self.cities = loadedCities
                self.habits = loadedHabits

                // Preselect default habits (steps, running, workout) if none selected
                if selectedHabitIds.isEmpty {
                    let defaultKeys = ["steps", "running", "workout"]
                    let defaultIds = loadedHabits.filter { defaultKeys.contains($0.key) }.map { $0.id }
                    self.selectedHabitIds = Set(defaultIds.isEmpty ? loadedHabits.prefix(3).map { $0.id } : defaultIds)
                }
            } catch {
                self.errorMessage = "Failed to load setup options: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }

    // MARK: - Filtered Cities
    public var filteredCities: [CityItem] {
        guard !citySearchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            return cities
        }
        let query = citySearchQuery.lowercased().trimmingCharacters(in: .whitespaces)
        return cities.filter {
            $0.name.lowercased().contains(query) || $0.country.lowercased().contains(query)
        }
    }

    // MARK: - Validation
    public func validateUsername() {
        let clean = username.lowercased().trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else {
            usernameValidationMessage = nil
            isUsernameValid = false
            return
        }

        if clean.count < 3 {
            usernameValidationMessage = "Must be at least 3 characters"
            isUsernameValid = false
            return
        }

        if clean.count > 20 {
            usernameValidationMessage = "Cannot exceed 20 characters"
            isUsernameValid = false
            return
        }

        let regex = "^[a-z0-9][a-z0-9_]{1,18}[a-z0-9]$"
        let isMatch = clean.range(of: regex, options: .regularExpression) != nil
        if !isMatch {
            if clean.hasPrefix("_") || clean.hasSuffix("_") {
                usernameValidationMessage = "Cannot start or end with underscore"
            } else {
                usernameValidationMessage = "Only lowercase letters, numbers, and underscores"
            }
            isUsernameValid = false
            return
        }

        if reservedUsernames.contains(clean) {
            usernameValidationMessage = "This username is reserved"
            isUsernameValid = false
            return
        }

        usernameValidationMessage = "✓ Username available"
        isUsernameValid = true
    }

    // MARK: - Navigation Control
    public var canProceed: Bool {
        switch currentStep {
        case .username:
            return isUsernameValid
        case .avatar:
            return !selectedAvatar.isEmpty
        case .city:
            return selectedCity != nil
        case .habits:
            return !selectedHabitIds.isEmpty
        case .permissions:
            return true // Optional primer step
        case .summary:
            return !isSubmitting
        }
    }

    public func nextStep() {
        guard canProceed else { return }
        HapticManager.shared.buttonTap()
        switch currentStep {
        case .username: currentStep = .avatar
        case .avatar: currentStep = .city
        case .city: currentStep = .habits
        case .habits: currentStep = .permissions
        case .permissions: currentStep = .summary
        case .summary: break
        }
    }

    public func previousStep() {
        HapticManager.shared.buttonTap()
        switch currentStep {
        case .username: break
        case .avatar: currentStep = .username
        case .city: currentStep = .avatar
        case .habits: currentStep = .city
        case .permissions: currentStep = .habits
        case .summary: currentStep = .permissions
        }
    }

    public func toggleHabit(id: Int64) {
        HapticManager.shared.selection()
        if selectedHabitIds.contains(id) {
            // Keep at least 1 habit selected
            if selectedHabitIds.count > 1 {
                selectedHabitIds.remove(id)
            }
        } else {
            selectedHabitIds.insert(id)
        }
    }

    public func requestHealthKitPermission() async {
        HapticManager.shared.buttonTap()
        let selectedKeys = habits.filter { selectedHabitIds.contains($0.id) }.map { $0.key }
        let keysToRequest = selectedKeys.isEmpty ? ["steps", "running", "workout", "hydration", "sleep", "mindfulness"] : selectedKeys
        do {
            _ = try await healthKitService.requestAuthorization(habitKeys: keysToRequest)
            self.healthKitRequested = true
            await syncService.startBackgroundObservers()
        } catch {
            // Still let user continue onboarding even if HealthKit unavailable in simulator
            self.healthKitRequested = true
        }
    }

    public func requestNotificationPermission() async {
        HapticManager.shared.buttonTap()
        _ = await NotificationManager.shared.requestAuthorization()
        self.notificationsRequested = true
    }

    // MARK: - Final Submission
    public func completeOnboarding(appState: AppState) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let cleanUsername = username.lowercased().trimmingCharacters(in: .whitespaces)
        let cleanDisplayName = displayName.trimmingCharacters(in: .whitespaces)

        do {
            // 1. Set unique username
            _ = try await profileService.setUsername(cleanUsername)

            // 2. Set city
            if let city = selectedCity {
                try await profileService.setCity(cityId: city.id)
            }

            // 3. Set habits
            if !selectedHabitIds.isEmpty {
                try await profileService.setUserHabits(habitIds: Array(selectedHabitIds))
            }

            // 4. Update profile with display name & avatar preset
            let updatedProfile = try await profileService.updateProfile(
                displayName: cleanDisplayName.isEmpty ? nil : cleanDisplayName,
                avatarPreset: selectedAvatar
            )

            HapticManager.shared.celebration()

            // 5. Kick off initial HealthKit sync in background
            Task {
                _ = try? await syncService.syncAllHabits()
            }

            // 6. Transition to authenticated state
            appState.activeProfile = updatedProfile
            appState.sessionStatus = .authenticated(updatedProfile)
        } catch let error as APIError {
            self.errorMessage = error.localizedDescription
            self.showError = true
            HapticManager.shared.error()
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
            HapticManager.shared.error()
        }
    }
}
