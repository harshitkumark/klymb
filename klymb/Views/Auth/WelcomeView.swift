//
//  WelcomeView.swift
//  klymb
//
//  Welcome & Sign-in screen matching docs/DESIGN_SYSTEM.md §8.2 & §9.
//  Dark gaming hero aesthetic with Sign in with Apple.
//

import SwiftUI
import AuthenticationServices

public struct WelcomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: AuthViewModel

    public init(viewModel: AuthViewModel? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel ?? AuthViewModel())
    }

    public var body: some View {
        ZStack {
            // Background
            Color.KlymbBackground.primary
                .ignoresSafeArea()

            // Subtle background glow
            Circle()
                .fill(Color.KlymbAccent.primary.opacity(0.12))
                .blur(radius: 80)
                .frame(width: 300, height: 300)
                .offset(y: -120)

            VStack(spacing: 0) {
                Spacer()

                // Hero Branding
                VStack(spacing: KlymbSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.KlymbBackground.secondary)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Circle()
                                    .stroke(Color.KlymbAccent.primary, lineWidth: 2)
                            )
                            .shadow(color: Color.KlymbAccent.primary.opacity(0.3), radius: 16)

                        Image(systemName: "flame.fill")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(KlymbGradient.fire)
                    }

                    Text("KLYMB")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(Color.KlymbText.primary)

                    Text("Your city is watching.")
                        .font(Font.Klymb.headline)
                        .foregroundStyle(Color.KlymbAccent.primary)

                    Text("Level up your lifestyle.\nCompete with your city. Earn KP. Climb the ranks.")
                        .font(Font.Klymb.body)
                        .foregroundStyle(Color.KlymbText.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, KlymbSpacing.xl)
                }

                Spacer()

                // Auth Action Section
                VStack(spacing: KlymbSpacing.md) {
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(Color.KlymbAccent.primary)
                            .frame(height: 52)
                    } else {
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: viewModel.configureAppleRequest,
                            onCompletion: { result in
                                viewModel.handleAppleCompletion(result, appState: appState)
                            }
                        )
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.lg))
                        .shadow(color: Color.white.opacity(0.15), radius: 8)

                        // Simulator / Dev bypass option
                        #if DEBUG
                        Button(action: {
                            viewModel.devBypassSignIn(appState: appState)
                        }) {
                            Text("Dev Quick Sign In")
                                .font(Font.Klymb.caption)
                                .foregroundStyle(Color.KlymbText.tertiary)
                        }
                        .padding(.top, 4)
                        #endif
                    }

                    // Terms and Privacy Notice
                    Text("By continuing, you agree to our Terms of Service and Privacy Policy.")
                        .font(Font.Klymb.captionSmall)
                        .foregroundStyle(Color.KlymbText.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, KlymbSpacing.lg)
                        .padding(.top, KlymbSpacing.xs)
                }
                .padding(.horizontal, KlymbSpacing.xl)
                .padding(.bottom, KlymbSpacing.xxl)
            }
        }
        .preferredColorScheme(.dark)
        .alert("Sign In Failed", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unexpected error occurred.")
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AppState())
}
