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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let container: AppContainerProtocol

    public init(container: AppContainerProtocol = AppContainer.mock) {
        self.container = container
    }

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
                        WelcomeView(container: container)
                    case .needsOnboarding:
                        OnboardingContainerView(container: container)
                    case .authenticated:
                        MainTabView(container: container)
                    }
                }

                // Global Offline Notification Banner
                if !networkMonitor.isConnected {
                    OfflineBannerView()
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        .zIndex(999)
                }
            }
        }
        .environmentObject(networkMonitor)
        .animation(reduceMotion ? nil : MotionTokens.springStandard, value: networkMonitor.isConnected)
        .task {
            await appState.checkCurrentSession()
        }
    }
}

private struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.KlymbBackground.primary.ignoresSafeArea()

            VStack {
                KlymbTopographicBackdrop(accentOpacity: 0.05)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: KlymbSpacing.md) {
                KlymbBrandMark(size: 30)

                Text("KLYMB")
                    .font(Font.Klymb.telemetry)
                    .tracking(4)
                    .foregroundStyle(Color.KlymbText.primary)

                ProgressView()
                    .tint(Color.KlymbAccent.primary)
                    .padding(.top, KlymbSpacing.xs)
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
