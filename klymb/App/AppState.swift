//
//  AppState.swift
//  klymb
//
//  Global application state managing authentication flow, active session,
//  and top-level routing.
//

import SwiftUI
import Combine

public enum SessionStatus: Equatable {
    case loading
    case unauthenticated
    case needsOnboarding(userId: UUID)
    case authenticated(Profile)
}

public enum MainTab: Hashable, CaseIterable {
    case home
    case log
    case compete
    case challenges
    case profile

    public var title: String {
        switch self {
        case .home: return "Home"
        case .log: return "Log"
        case .compete: return "Compete"
        case .challenges: return "Challenges"
        case .profile: return "Profile"
        }
    }

    public var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .log: return "plus.circle.fill"
        case .compete: return "trophy.fill"
        case .challenges: return "flag.checkered"
        case .profile: return "person.crop.circle"
        }
    }
}

@MainActor
public final class AppState: ObservableObject {
    @Published public var sessionStatus: SessionStatus = .loading
    @Published public var selectedTab: MainTab = .home
    @Published public var activeProfile: Profile?

    private let container: AppContainerProtocol

    public init(container: AppContainerProtocol = AppContainer.mock) {
        self.container = container
    }

    public func checkCurrentSession() async {
        do {
            if let profile = try await container.authService.getCurrentProfile() {
                self.activeProfile = profile
                self.sessionStatus = .authenticated(profile)
            } else {
                self.activeProfile = nil
                self.sessionStatus = .unauthenticated
            }
        } catch {
            self.activeProfile = nil
            self.sessionStatus = .unauthenticated
        }
    }

    public func signOut() async {
        do {
            try await container.authService.signOut()
            self.activeProfile = nil
            self.sessionStatus = .unauthenticated
        } catch {
            self.sessionStatus = .unauthenticated
        }
    }
}
