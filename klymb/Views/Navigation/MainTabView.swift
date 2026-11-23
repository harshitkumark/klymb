//
//  MainTabView.swift
//  klymb
//
//  5-tab navigation bar (Home, Log, Compete, Challenges, Profile)
//  with Dynamic Type & VoiceOver support (AGENTS.md Rule 18).
//

import SwiftUI

public struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
            .tabItem {
                Label(MainTab.home.title, systemImage: MainTab.home.iconName)
            }
            .tag(MainTab.home)

            ManualLogView()
            .tabItem {
                Label(MainTab.log.title, systemImage: MainTab.log.iconName)
            }
            .tag(MainTab.log)

            CompeteView()
            .tabItem {
                Label(MainTab.compete.title, systemImage: MainTab.compete.iconName)
            }
            .tag(MainTab.compete)

            ChallengesView()
            .tabItem {
                Label(MainTab.challenges.title, systemImage: MainTab.challenges.iconName)
            }
            .tag(MainTab.challenges)

            ProfileView()
            .tabItem {
                Label(MainTab.profile.title, systemImage: MainTab.profile.iconName)
            }
            .tag(MainTab.profile)
        }
        .tint(ColorTokens.electricCyan)
        .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
