//
//  ProfileView.swift
//  klymb
//
//  Profile Tab: Horizontal Athlete Pass, Tier Progression, 2x2 Bento Stats,
//  Achievements Showcase Grid, and Account Navigation.
//

import SwiftUI

public struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ProfileViewModel
    @State private var showNotificationPreferences: Bool = false
    @State private var showSettings: Bool = false
    private let container: AppContainerProtocol

    public init(container: AppContainerProtocol = AppContainer.mock) {
        self.container = container
        _viewModel = StateObject(wrappedValue: ProfileViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.KlymbBackground.primary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: KlymbSpacing.lg) {
                        // 1. Top Header with Notifications & Settings
                        HStack(alignment: .center) {
                            Text("Profile")
                                .font(Font.Klymb.titleLarge)
                                .foregroundStyle(Color.KlymbText.primary)

                            Spacer()

                            HStack(spacing: KlymbSpacing.sm) {
                                HeaderCircleButton(
                                    icon: "bell.badge",
                                    accessibilityLabel: "Notification Settings"
                                ) {
                                    showNotificationPreferences = true
                                }

                                HeaderCircleButton(
                                    icon: "gearshape.fill",
                                    accessibilityLabel: "App Settings"
                                ) {
                                    showSettings = true
                                }
                            }
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        .padding(.top, KlymbSpacing.sm)

                        // 2. Athlete Pass Identity Card
                        ProfileHeroCard(viewModel: viewModel)
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        // 3. 2x2 Stats Bento Grid
                        ProfileStatsGrid(viewModel: viewModel)
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        // 4. Achievements Showcase
                        AchievementsShowcaseSection(viewModel: viewModel)
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        // 5. Unified Account Actions
                        ProfileAccountSection(
                            appState: appState,
                            onOpenNotifications: { showNotificationPreferences = true },
                            onOpenSettings: { showSettings = true }
                        )
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        Spacer(minLength: KlymbSpacing.xl)
                    }
                    .padding(.bottom, KlymbSpacing.xl)
                }
                .refreshable {
                    await viewModel.loadProfile()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadProfile()
            }
            .sheet(item: $viewModel.selectedAchievement) { achievement in
                AchievementDetailSheet(achievement: achievement) {
                    viewModel.dismissAchievementDetail()
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showNotificationPreferences) {
                NotificationPreferencesView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(container: container)
            }
        }
    }
}

private struct HeaderCircleButton: View {
    let icon: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.KlymbBackground.secondary)
                    .frame(width: 38, height: 38)
                    .overlay(
                        Circle().strokeBorder(KlymbGradient.specularBorder, lineWidth: 1)
                    )

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.KlymbText.primary)
            }
        }
        .buttonStyle(KlymbPressableButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - 1. Athlete Pass Card
private struct ProfileHeroCard: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        VStack(spacing: KlymbSpacing.lg) {
            HStack(spacing: KlymbSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous)
                        .fill(Color.KlymbAccent.primaryMuted)
                        .frame(width: 68, height: 68)
                        .overlay(
                            RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous)
                                .strokeBorder(viewModel.rankTier.tierColor.opacity(0.7), lineWidth: 1.5)
                        )

                    Image(systemName: KlymbIconCatalog.avatarIcon(for: viewModel.profile?.avatarPreset))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(viewModel.rankTier.tierColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.profile?.displayName ?? viewModel.profile?.title ?? "Athlete")
                        .font(Font.Klymb.titleSmall)
                        .foregroundStyle(Color.KlymbText.primary)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Text("@\(viewModel.profile?.username ?? "athlete")")
                        if let city = viewModel.profile?.cityName {
                            Text("• \(city)")
                        }
                    }
                    .font(Font.Klymb.caption)
                    .foregroundStyle(Color.KlymbText.secondary)
                    .lineLimit(1)

                    HStack(spacing: 5) {
                        Image(systemName: viewModel.rankTier.iconName)
                            .font(.system(size: 10, weight: .bold))
                        Text(viewModel.rankTier.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(viewModel.rankTier.tierColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(viewModel.rankTier.tierColor.opacity(0.14))
                    .clipShape(Capsule())
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)
            }

            // Clean Tier Progress Bar
            VStack(spacing: 6) {
                HStack {
                    Text("\(viewModel.totalKP.formatted()) KP")
                        .font(Font.Klymb.telemetry)
                        .monospacedDigit()
                        .foregroundStyle(Color.KlymbText.primary)

                    Spacer()

                    if let delta = viewModel.kpToNextTier, let next = viewModel.rankTier.nextTierThreshold {
                        Text("\(delta.formatted()) KP to \(next.formatted())")
                            .font(Font.Klymb.telemetry)
                            .monospacedDigit()
                            .foregroundStyle(Color.KlymbText.secondary)
                    } else {
                        Text("MAX TIER")
                            .font(Font.Klymb.telemetry)
                            .foregroundStyle(Color.KlymbAccent.soft)
                    }
                }

                KlymbProgressBar(
                    progress: viewModel.tierProgressRatio,
                    height: 5,
                    fillOverride: LinearGradient(
                        colors: [viewModel.rankTier.tierColor, Color.KlymbAccent.soft],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
        }
        .padding(KlymbSpacing.lg)
        .background(
            LinearGradient(
                colors: [
                    Color.KlymbAccent.primary.opacity(0.11),
                    Color.KlymbBackground.secondary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KlymbRadius.xl, style: .continuous)
                .strokeBorder(Color.KlymbAccent.primary.opacity(0.28), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.profile?.displayName ?? "Athlete"), \(viewModel.rankTier.rawValue), \(viewModel.totalKP) Total KP")
    }
}

// MARK: - 2. 2x2 Bento Stats Grid
private struct ProfileStatsGrid: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        VStack(spacing: KlymbSpacing.md) {
            HStack(spacing: KlymbSpacing.md) {
                StatTile(
                    icon: "bolt.fill",
                    value: "\(viewModel.totalKP.formatted()) KP",
                    label: "Lifetime Score",
                    valueColor: Color.KlymbAccent.soft
                )

                StatTile(
                    icon: "flame.fill",
                    value: "\(viewModel.streak.currentStreak)d",
                    label: "Current Streak",
                    valueColor: Color.KlymbAccent.primary
                )
            }

            HStack(spacing: KlymbSpacing.md) {
                StatTile(
                    icon: "trophy.fill",
                    value: "\(viewModel.streak.longestStreak)d",
                    label: "Best Streak",
                    valueColor: Color.KlymbRank.gold
                )

                StatTile(
                    icon: "rosette",
                    value: "\(viewModel.unlockedCount) / \(viewModel.achievements.count)",
                    label: "Achievements",
                    valueColor: Color.KlymbText.secondary
                )
            }
        }
    }
}

// MARK: - 3. Achievements Showcase
private struct AchievementsShowcaseSection: View {
    @ObservedObject var viewModel: ProfileViewModel

    private let columns = [
        GridItem(.flexible(), spacing: KlymbSpacing.md),
        GridItem(.flexible(), spacing: KlymbSpacing.md)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: KlymbSpacing.md) {
            KlymbSectionHeader(
                "Achievements",
                trailingText: "\(viewModel.unlockedCount) UNLOCKED",
                trailingColor: Color.KlymbAccent.soft
            )

            // Underlined Filter Strip
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: KlymbSpacing.lg) {
                        ForEach(AchievementCategoryFilter.allCases) { filter in
                            let isSelected = (filter == viewModel.selectedFilter)

                            Button {
                                viewModel.setFilter(filter)
                            } label: {
                                VStack(spacing: 7) {
                                    Text(filter.title)
                                        .font(Font.Klymb.caption.weight(.semibold))
                                        .foregroundStyle(isSelected ? Color.KlymbAccent.soft : Color.KlymbText.secondary)

                                    Rectangle()
                                        .fill(isSelected ? Color.KlymbAccent.primary : Color.clear)
                                        .frame(height: 2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Divider().background(Color.KlymbBorder.subtle)
            }

            LazyVGrid(columns: columns, spacing: KlymbSpacing.md) {
                ForEach(viewModel.filteredAchievements) { achievement in
                    AchievementCard(achievement: achievement) {
                        viewModel.selectAchievement(achievement)
                    }
                }
            }
        }
    }
}

private struct AchievementCard: View {
    let achievement: Achievement
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: KlymbSpacing.sm) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: KlymbRadius.sm, style: .continuous)
                            .fill(achievement.isUnlocked ? Color.KlymbAccent.primaryMuted : Color.KlymbBackground.tertiary)
                            .frame(width: 34, height: 34)
                            .overlay(
                                RoundedRectangle(cornerRadius: KlymbRadius.sm, style: .continuous)
                                    .strokeBorder(
                                        achievement.isUnlocked ? achievement.tierColor.opacity(0.45) : Color.KlymbBorder.subtle,
                                        lineWidth: 1
                                    )
                            )

                        Image(systemName: achievement.isUnlocked ? achievement.iconName : "lock.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(achievement.isUnlocked ? achievement.tierColor : Color.KlymbText.tertiary)
                    }

                    Spacer()

                    Text("+\(achievement.rewardKP) KP")
                        .font(Font.Klymb.telemetry)
                        .foregroundStyle(achievement.isUnlocked ? Color.KlymbAccent.soft : Color.KlymbText.tertiary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(achievement.displayName)
                        .font(Font.Klymb.caption.weight(.semibold))
                        .foregroundStyle(achievement.isUnlocked ? Color.KlymbText.primary : Color.KlymbText.secondary)
                        .lineLimit(1)

                    Text("\(achievement.tier.capitalized) Tier")
                        .font(Font.Klymb.captionSmall)
                        .foregroundStyle(Color.KlymbText.tertiary)
                }
            }
            .padding(KlymbSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .klymbCardStyle(
                cornerRadius: KlymbRadius.lg,
                isElevated: achievement.isUnlocked
            )
            .opacity(achievement.isUnlocked ? 1.0 : 0.65)
        }
        .buttonStyle(KlymbPressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.displayName), \(achievement.tier) tier badge, \(achievement.isUnlocked ? "unlocked" : "locked"), reward \(achievement.rewardKP) KP")
    }
}

// MARK: - Achievement Detail Sheet
private struct AchievementDetailSheet: View {
    let achievement: Achievement
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: KlymbSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(achievement.isUnlocked ? achievement.tierColor.opacity(0.16) : Color.KlymbBackground.tertiary)
                        .frame(width: 84, height: 84)

                    Image(systemName: achievement.iconName)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(achievement.isUnlocked ? achievement.tierColor : Color.KlymbText.tertiary)
                }
                .overlay(
                    Circle()
                        .strokeBorder(achievement.isUnlocked ? achievement.tierColor.opacity(0.8) : Color.KlymbBorder.default, lineWidth: 2)
                )
                .padding(.top, KlymbSpacing.md)

                VStack(spacing: 6) {
                    Text("\(achievement.tier.uppercased()) BADGE")
                        .font(Font.Klymb.telemetry)
                        .foregroundStyle(achievement.tierColor)

                    Text(achievement.displayName)
                        .font(Font.Klymb.titleSmall)
                        .foregroundStyle(Color.KlymbText.primary)

                    if let desc = achievement.description {
                        Text(desc)
                            .font(Font.Klymb.bodySmall)
                            .foregroundStyle(Color.KlymbText.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    }
                }

                HStack(spacing: KlymbSpacing.md) {
                    StatTile(
                        icon: "trophy.fill",
                        value: "+\(achievement.rewardKP) KP",
                        label: "Reward",
                        valueColor: Color.KlymbRank.gold
                    )

                    StatTile(
                        icon: achievement.isUnlocked ? "checkmark.circle.fill" : "lock.fill",
                        value: achievement.isUnlocked ? "Unlocked" : "Locked",
                        label: "Status",
                        valueColor: achievement.isUnlocked ? Color.KlymbSemantic.success : Color.KlymbText.tertiary
                    )
                }
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                Spacer()

                PrimaryButton("Done") {
                    onClose()
                }
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                .padding(.bottom, KlymbSpacing.md)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.KlymbBackground.primary.ignoresSafeArea())
            .navigationTitle("Achievement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onClose)
                        .foregroundStyle(Color.KlymbAccent.soft)
                }
            }
        }
    }
}

// MARK: - 4. Unified Account Actions
private struct ProfileAccountSection: View {
    @ObservedObject var appState: AppState
    let onOpenNotifications: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KlymbSpacing.md) {
            KlymbSectionHeader("Account")

            KlymbGroupedSurface {
                AccountRowButton(
                    icon: "gearshape.fill",
                    title: "Settings & Privacy",
                    action: onOpenSettings
                )
                .accessibilityLabel("Open Settings and Privacy")

                Divider()
                    .background(Color.KlymbBorder.subtle)
                    .padding(.leading, 48)

                AccountRowButton(
                    icon: "bell.badge.fill",
                    title: "Push Notifications",
                    action: onOpenNotifications
                )
                .accessibilityLabel("Open Push Notification Preferences")
            }

            Button(role: .destructive) {
                Task {
                    await appState.signOut()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Sign Out")
                }
                .font(Font.Klymb.bodySmall.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(Color.KlymbSemantic.error.opacity(0.10))
                .foregroundStyle(Color.KlymbSemantic.error)
                .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous)
                        .strokeBorder(Color.KlymbSemantic.error.opacity(0.28), lineWidth: 1)
                )
            }
            .buttonStyle(KlymbPressableButtonStyle())

            Text("Klymb iOS • v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") (Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                .font(Font.Klymb.captionSmall)
                .foregroundStyle(Color.KlymbText.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

private struct AccountRowButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KlymbSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.KlymbAccent.soft)
                    .frame(width: 24)

                Text(title)
                    .font(Font.Klymb.bodySmall.weight(.semibold))
                    .foregroundStyle(Color.KlymbText.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.KlymbText.tertiary)
            }
            .padding(.horizontal, KlymbSpacing.lg)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
