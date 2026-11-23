//
//  ProfileView.swift
//  klymb
//
//  Profile Tab: Athlete Card, Rank Tier Progress, Lifetime Stats,
//  and Achievements Showcase Grid (PRD §F11 & Design System §9.9).
//  Follows AGENTS.md Rules 1, 2, 15, 18.
//

import SwiftUI

public struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ProfileViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(container: AppContainerProtocol = AppContainer.mock) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LayoutTokens.spacingL) {
                    // 1. Hero Athlete Card & Tier Progression
                    ProfileHeroCard(viewModel: viewModel)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        .padding(.top, LayoutTokens.spacingS)

                    // 2. Core Stats 2x2 Grid
                    ProfileStatsGrid(viewModel: viewModel)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    // 3. Achievements Showcase Section
                    AchievementsShowcaseSection(viewModel: viewModel)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    // 4. Account Actions
                    ProfileAccountSection(appState: appState)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        .padding(.top, LayoutTokens.spacingM)

                    Spacer(minLength: 40)
                }
                .padding(.bottom, LayoutTokens.spacingXXL)
            }
            .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(ColorTokens.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable {
                await viewModel.loadProfile()
            }
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
        }
    }
}

// MARK: - 1. Hero Athlete Card
private struct ProfileHeroCard: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        VStack(spacing: LayoutTokens.spacingM) {
            // Avatar with Tier Ring
            ZStack {
                Circle()
                    .fill(ColorTokens.backgroundTertiary)
                    .frame(width: 90, height: 90)

                Image(systemName: avatarIcon(for: viewModel.profile?.avatarPreset))
                    .font(.system(size: 42))
                    .foregroundStyle(viewModel.rankTier.tierColor)

                // Tier badge overlay
                Image(systemName: viewModel.rankTier.iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black)
                    .padding(5)
                    .background(viewModel.rankTier.tierColor)
                    .clipShape(Circle())
                    .offset(x: 32, y: 32)
            }
            .overlay(
                Circle()
                    .strokeBorder(viewModel.rankTier.tierColor.opacity(0.8), lineWidth: 2.5)
            )

            // Names & City
            VStack(spacing: 4) {
                Text(viewModel.profile?.displayName ?? "Champion Dev")
                    .font(TypographyTokens.title2)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("@\(viewModel.profile?.username ?? "champion_dev")")
                    .font(TypographyTokens.subheadline)
                    .foregroundStyle(ColorTokens.textTertiary)

                if let city = viewModel.profile?.cityName {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                        Text(city)
                            .font(TypographyTokens.caption1)
                    }
                    .foregroundStyle(ColorTokens.electricCyan)
                    .padding(.top, 2)
                }
            }

            // Tier Rank Tag
            HStack(spacing: 6) {
                Image(systemName: viewModel.rankTier.iconName)
                    .font(.system(size: 12, weight: .bold))
                Text(viewModel.rankTier.rawValue.uppercased())
                    .font(.system(size: 11, weight: .heavy))
            }
            .foregroundStyle(viewModel.rankTier.tierColor)
            .padding(.horizontal, LayoutTokens.paddingM)
            .padding(.vertical, 6)
            .background(viewModel.rankTier.tierColor.opacity(0.15))
            .clipShape(Capsule())

            // Tier Progress Bar
            VStack(spacing: 6) {
                HStack {
                    Text("\(viewModel.totalKP) KP")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(ColorTokens.textPrimary)

                    Spacer()

                    if let next = viewModel.rankTier.nextTierThreshold {
                        Text("\(next) KP")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ColorTokens.backgroundTertiary)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [viewModel.rankTier.tierColor, ColorTokens.electricCyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(viewModel.tierProgressRatio), height: 8)
                    }
                }
                .frame(height: 8)

                if let delta = viewModel.kpToNextTier {
                    Text("⚡️ \(delta) KP to reach next rank tier")
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
            }
            .padding(.top, 4)
        }
        .padding(LayoutTokens.paddingL)
        .background(
            RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                .fill(ColorTokens.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                .strokeBorder(viewModel.rankTier.tierColor.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.profile?.displayName ?? "Champion"), \(viewModel.rankTier.rawValue), \(viewModel.totalKP) Total KP")
    }

    private func avatarIcon(for preset: String?) -> String {
        switch preset {
        case "sprinter": return "flame.fill"
        case "climber": return "figure.climbing"
        case "cyclist": return "figure.outdoor.cycle"
        case "zen": return "figure.mind.and.body"
        case "star": return "star.fill"
        case "bolt": return "bolt.fill"
        default: return "figure.run"
        }
    }
}

// MARK: - 2. Core Stats Grid
private struct ProfileStatsGrid: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        VStack(spacing: LayoutTokens.spacingM) {
            HStack(spacing: LayoutTokens.spacingM) {
                StatTile(
                    icon: "bolt.fill",
                    value: "\(viewModel.totalKP) KP",
                    label: "TOTAL SCORE",
                    valueColor: ColorTokens.electricCyan
                )

                StatTile(
                    icon: "flame.fill",
                    value: "\(viewModel.streak.currentStreak) Days",
                    label: "CURRENT STREAK",
                    valueColor: ColorTokens.neonOrange
                )
            }

            HStack(spacing: LayoutTokens.spacingM) {
                StatTile(
                    icon: "trophy.fill",
                    value: "\(viewModel.streak.longestStreak) Days",
                    label: "BEST STREAK",
                    valueColor: Color.KlymbRank.gold
                )

                StatTile(
                    icon: "rosette",
                    value: "\(viewModel.unlockedCount) / \(viewModel.achievements.count)",
                    label: "BADGES WON",
                    valueColor: ColorTokens.neonPurple
                )
            }
        }
    }
}

// MARK: - 3. Achievements Showcase Section
private struct AchievementsShowcaseSection: View {
    @ObservedObject var viewModel: ProfileViewModel

    private let columns = [
        GridItem(.flexible(), spacing: LayoutTokens.spacingM),
        GridItem(.flexible(), spacing: LayoutTokens.spacingM)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutTokens.spacingM) {
            // Header Title
            HStack {
                Text("ACHIEVEMENT BADGES")
                    .font(TypographyTokens.caption1.bold())
                    .foregroundStyle(ColorTokens.textTertiary)

                Spacer()

                Text("\(viewModel.unlockedCount) UNLOCKED")
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.electricCyan)
            }

            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LayoutTokens.spacingS) {
                    ForEach(AchievementCategoryFilter.allCases) { filter in
                        let isSelected = (filter == viewModel.selectedFilter)

                        Button {
                            viewModel.setFilter(filter)
                        } label: {
                            Text(filter.title)
                                .font(TypographyTokens.caption1.weight(.semibold))
                                .padding(.horizontal, LayoutTokens.paddingM)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? ColorTokens.electricCyan.opacity(0.18) : ColorTokens.backgroundSecondary)
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(isSelected ? ColorTokens.electricCyan : ColorTokens.borderSubtle, lineWidth: 1)
                                )
                                .foregroundStyle(isSelected ? ColorTokens.electricCyan : ColorTokens.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Grid of Badges
            LazyVGrid(columns: columns, spacing: LayoutTokens.spacingM) {
                ForEach(viewModel.filteredAchievements) { achievement in
                    AchievementCard(achievement: achievement) {
                        viewModel.selectAchievement(achievement)
                    }
                }
            }
        }
    }
}

// MARK: - Achievement Card
private struct AchievementCard: View {
    let achievement: Achievement
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: LayoutTokens.spacingS) {
                // Badge Icon
                ZStack {
                    RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                        .fill(achievement.isUnlocked ? achievement.tierColor.opacity(0.18) : ColorTokens.backgroundTertiary)
                        .frame(width: 58, height: 58)

                    Image(systemName: achievement.iconName)
                        .font(.system(size: 26))
                        .foregroundStyle(achievement.isUnlocked ? achievement.tierColor : ColorTokens.textTertiary)

                    if !achievement.isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .offset(x: 20, y: 20)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                        .strokeBorder(
                            achievement.isUnlocked ? achievement.tierColor.opacity(0.6) : ColorTokens.borderSubtle,
                            lineWidth: achievement.isUnlocked ? 1.5 : 1
                        )
                )

                // Title
                Text(achievement.displayName)
                    .font(TypographyTokens.caption1.bold())
                    .foregroundStyle(achievement.isUnlocked ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                    .lineLimit(1)

                // Reward & Tier
                HStack(spacing: 4) {
                    Text("+\(achievement.rewardKP) KP")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(achievement.isUnlocked ? Color.KlymbRank.gold : ColorTokens.textTertiary)

                    Text("•")
                        .font(.system(size: 8))
                        .foregroundStyle(ColorTokens.textTertiary)

                    Text(achievement.tier.capitalized)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(achievement.tierColor)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(LayoutTokens.paddingM)
            .background(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                    .fill(ColorTokens.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                    .strokeBorder(
                        achievement.isUnlocked ? achievement.tierColor.opacity(0.3) : ColorTokens.borderSubtle,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
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
            VStack(spacing: LayoutTokens.spacingL) {
                // Large Badge
                ZStack {
                    Circle()
                        .fill(achievement.isUnlocked ? achievement.tierColor.opacity(0.18) : ColorTokens.backgroundTertiary)
                        .frame(width: 88, height: 88)

                    Image(systemName: achievement.iconName)
                        .font(.system(size: 40))
                        .foregroundStyle(achievement.isUnlocked ? achievement.tierColor : ColorTokens.textTertiary)
                }
                .overlay(
                    Circle()
                        .strokeBorder(achievement.isUnlocked ? achievement.tierColor : ColorTokens.borderSubtle, lineWidth: 2)
                )
                .padding(.top, LayoutTokens.spacingM)

                // Title & Tier
                VStack(spacing: 6) {
                    Text("\(achievement.tier.uppercased()) BADGE")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(achievement.tierColor)

                    Text(achievement.displayName)
                        .font(TypographyTokens.title2)
                        .foregroundStyle(ColorTokens.textPrimary)

                    if let desc = achievement.description {
                        Text(desc)
                            .font(TypographyTokens.body)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    }
                }

                // Reward & Status
                HStack(spacing: LayoutTokens.spacingM) {
                    StatTile(
                        icon: "trophy.fill",
                        value: "+\(achievement.rewardKP) KP",
                        label: "REWARD",
                        valueColor: Color.KlymbRank.gold
                    )

                    StatTile(
                        icon: achievement.isUnlocked ? "checkmark.circle.fill" : "lock.fill",
                        value: achievement.isUnlocked ? "UNLOCKED" : "LOCKED",
                        label: "STATUS",
                        valueColor: achievement.isUnlocked ? ColorTokens.neonGreen : ColorTokens.textTertiary
                    )
                }
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                Spacer()

                PrimaryButton("Done") {
                    onClose()
                }
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                .padding(.bottom, LayoutTokens.spacingM)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Achievement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onClose)
                        .foregroundStyle(ColorTokens.electricCyan)
                }
            }
        }
    }
}

// MARK: - 4. Account Actions
private struct ProfileAccountSection: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: LayoutTokens.spacingM) {
            Button(role: .destructive) {
                Task {
                    await appState.signOut()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out (Switch Account)")
                }
                .font(TypographyTokens.subheadline.bold())
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(ColorTokens.neonRed.opacity(0.12))
                .foregroundStyle(ColorTokens.neonRed)
                .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusL))
                .overlay(
                    RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                        .strokeBorder(ColorTokens.neonRed.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Text("Klymb iOS • v1.0.0 (Build 42)")
                .font(TypographyTokens.caption2)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
