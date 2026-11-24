//
//  AuthViewModel.swift
//  klymb
//
//  Authentication ViewModel coordinating Sign in with Apple and session routing.
//  (AGENTS.md Rule 15: SwiftUI + MVVM).
//

import SwiftUI
import Combine
import AuthenticationServices

@MainActor
public final class AuthViewModel: ObservableObject {
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var showError: Bool = false

    private let authService: AuthServiceProtocol
    private let profileService: ProfileServiceProtocol

    public init(container: AppContainerProtocol = AppContainer.mock) {
        self.authService = container.authService
        self.profileService = container.profileService
    }

    public func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleSignInHelper.shared.generateNonce()
    }

    public func handleAppleCompletion(
        _ result: Result<ASAuthorization, Error>,
        appState: AppState
    ) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let rawNonce = AppleSignInHelper.shared.consumeNonce() else {
                self.errorMessage = "Failed to process Apple ID credentials."
                self.showError = true
                HapticManager.shared.error()
                return
            }

            Task {
                await processSignIn(idToken: idToken, nonce: rawNonce, appState: appState)
            }

        case .failure(let error):
            // User cancelled is not an alertable error
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                return
            }
            self.errorMessage = error.localizedDescription
            self.showError = true
            HapticManager.shared.error()
        }
    }

    /// Development sign-in / sign-up via Supabase Email Auth for Simulator testing
    public func devSignInWithEmail(email: String, password: String, isSignUp: Bool, appState: AppState) {
        Task {
            await processEmailSignIn(email: email, password: password, isSignUp: isSignUp, appState: appState)
        }
    }

    /// Fallback dev bypass for unit tests / mock container
    public func devBypassSignIn(appState: AppState) {
        Task {
            await processSignIn(idToken: "mock_id_token", nonce: "mock_nonce", appState: appState)
        }
    }

    private func processEmailSignIn(email: String, password: String, isSignUp: Bool, appState: AppState) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let profile: Profile
            if isSignUp {
                profile = try await authService.signUpWithEmail(email: email, password: password)
            } else {
                profile = try await authService.signInWithEmail(email: email, password: password)
            }
            HapticManager.shared.buttonTap()
            routeAfterSignIn(profile: profile, appState: appState)
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

    private func processSignIn(idToken: String, nonce: String, appState: AppState) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let profile = try await authService.signInWithApple(idToken: idToken, nonce: nonce)
            HapticManager.shared.buttonTap()
            routeAfterSignIn(profile: profile, appState: appState)
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

    private func routeAfterSignIn(profile: Profile, appState: AppState) {
        let isDefaultUsername = profile.username.hasPrefix("user_") || profile.username.isEmpty
        let hasCity = profile.cityId != nil

        if isDefaultUsername || !hasCity {
            appState.activeProfile = profile
            appState.sessionStatus = .needsOnboarding(userId: profile.id)
        } else {
            appState.activeProfile = profile
            appState.sessionStatus = .authenticated(profile)
        }
    }
}
