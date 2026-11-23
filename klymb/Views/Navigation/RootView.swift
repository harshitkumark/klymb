//
//  RootView.swift
//  klymb
//
//  Root view switching between loading, auth, onboarding, and main app.
//

import SwiftUI

public struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var versionInfo = AppVersionInfo()

    public init() {}

    public var body: some View {
        ZStack(alignment: .top) {
            if versionInfo.isUpdateRequired {
                ForceUpdateView(versionInfo: versionInfo) {
                    versionInfo.forceUpdateEnabled = false
                }
            } else {
                Group {
                    switch appState.sessionStatus {
                    case .loading:
                        LoadingView()
                    case .unauthenticated:
                        WelcomeView()
                    case .needsOnboarding:
                        OnboardingContainerView()
                    case .authenticated:
                        MainTabView()
                    }
                }

                // Global Offline Notification Banner
                if !networkMonitor.isConnected {
                    OfflineBannerView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(999)
                }
            }
        }
        .environmentObject(networkMonitor)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: networkMonitor.isConnected)
        .task {
            await appState.checkCurrentSession()
        }
    }
}

private struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.3)
                Text("KLYMB")
                    .font(.title.bold())
                    .tracking(4)
            }
        }
    }
}

private struct WelcomePlaceholderView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.accentColor)

                Text("KLYMB")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .tracking(2)

                Text("Level up your lifestyle.\nCompete. Earn KP. Climb.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                Button {
                    // Quick dev login for preview
                    Task {
                        await appState.checkCurrentSession()
                    }
                } label: {
                    Text("Continue with Apple")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

private struct OnboardingPlaceholderView: View {
    var body: some View {
        VStack {
            Text("Onboarding")
                .font(.title)
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}
