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
            PlaceholderScreen(
                title: "Home",
                subtitle: "Daily Habits, KP Counter & Streak",
                icon: "house.fill"
            )
            .tabItem {
                Label(MainTab.home.title, systemImage: MainTab.home.iconName)
            }
            .tag(MainTab.home)

            PlaceholderScreen(
                title: "Log Activity",
                subtitle: "Manual logging for Water, Workout, Mindfulness",
                icon: "plus.circle.fill"
            )
            .tabItem {
                Label(MainTab.log.title, systemImage: MainTab.log.iconName)
            }
            .tag(MainTab.log)

            PlaceholderScreen(
                title: "Compete",
                subtitle: "City, Global & Friends Leaderboards",
                icon: "trophy.fill"
            )
            .tabItem {
                Label(MainTab.compete.title, systemImage: MainTab.compete.iconName)
            }
            .tag(MainTab.compete)

            PlaceholderScreen(
                title: "Challenges",
                subtitle: "Daily, Weekly & Community Goals",
                icon: "flag.checkered"
            )
            .tabItem {
                Label(MainTab.challenges.title, systemImage: MainTab.challenges.iconName)
            }
            .tag(MainTab.challenges)

            PlaceholderScreen(
                title: "Profile",
                subtitle: "KP Stats, Achievements & Settings",
                icon: "person.crop.circle"
            )
            .tabItem {
                Label(MainTab.profile.title, systemImage: MainTab.profile.iconName)
            }
            .tag(MainTab.profile)
        }
        .tint(Color.accentColor)
    }
}

private struct PlaceholderScreen: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle(title)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
