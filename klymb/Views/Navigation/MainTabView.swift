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
        .tint(ColorTokens.electricCyan)
        .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
    }
}

private struct PlaceholderScreen: View {
    let title: String
    let subtitle: String
    let icon: String
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: LayoutTokens.spacingM) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(ColorTokens.backgroundSecondary)
                        .frame(width: 90, height: 90)

                    Image(systemName: icon)
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(ColorTokens.electricCyan)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(TypographyTokens.title1)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(TypographyTokens.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                if title == "Profile" {
                    Button(role: .destructive) {
                        Task {
                            await appState.signOut()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out (Test Welcome & Onboarding)")
                        }
                        .font(TypographyTokens.caption1.bold())
                        .padding(.horizontal, LayoutTokens.paddingM)
                        .padding(.vertical, LayoutTokens.paddingS)
                        .background(ColorTokens.neonRed.opacity(0.15))
                        .foregroundStyle(ColorTokens.neonRed)
                        .clipShape(Capsule())
                    }
                    .padding(.top, LayoutTokens.spacingL)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
            .navigationTitle(title)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
