//
//  MainTabView.swift
//  klymb
//
//  5-tab navigation bar (Home, Log, Compete, Challenges, Profile)
//  matching Matte Charcoal & Velvet Terracotta aesthetic (AGENTS.md Rule 18).
//

import SwiftUI

public struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    private let container: AppContainerProtocol

    public init(container: AppContainerProtocol = AppContainer.mock) {
        self.container = container
    }

    public var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView(container: container)
                .tabItem {
                    Label(MainTab.home.title, systemImage: MainTab.home.iconName)
                }
                .tag(MainTab.home)

            ManualLogView(container: container)
                .tabItem {
                    Label(MainTab.log.title, systemImage: MainTab.log.iconName)
                }
                .tag(MainTab.log)

            CompeteView(container: container)
                .tabItem {
                    Label(MainTab.compete.title, systemImage: MainTab.compete.iconName)
                }
                .tag(MainTab.compete)

            ChallengesView(container: container)
                .tabItem {
                    Label(MainTab.challenges.title, systemImage: MainTab.challenges.iconName)
                }
                .tag(MainTab.challenges)

            ProfileView(container: container)
                .tabItem {
                    Label(MainTab.profile.title, systemImage: MainTab.profile.iconName)
                }
                .tag(MainTab.profile)
        }
        .tint(Color.KlymbAccent.primary)
        .background(Color.KlymbBackground.primary.ignoresSafeArea())
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
