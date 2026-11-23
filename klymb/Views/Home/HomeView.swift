//
//  HomeView.swift
//  klymb
//
//  Home dashboard screen matching PRD §F20 & DESIGN_SYSTEM.md §8.1.
//  Hero KP counter, streak flame, daily habit progress, city overtake nudge,
//  and active challenge status.
//

import SwiftUI

public struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: HomeViewModel

    public init(container: AppContainerProtocol = AppContainer.mock) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LayoutTokens.spacingL) {
                    // 1. Top Greeting & Streak Bar
                    HomeTopBar(viewModel: viewModel)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        .padding(.top, LayoutTokens.spacingS)

                    // 2. Hero KP Ring Card
                    HomeHeroKPCard(viewModel: viewModel)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    // 3. Leaderboard Overtake Nudge Card
                    if let nudge = viewModel.overtakeNudge {
                        HomeOvertakeNudgeCard(nudge: nudge) {
                            appState.selectedTab = .compete
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    }

                    // 4. Daily Habits / Disciplines Progress
                    HomeHabitsSection(habits: viewModel.habitProgresses)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    // 5. Active Challenge Card
                    if let challenge = viewModel.activeChallenge {
                        HomeChallengeBanner(challenge: challenge) {
                            appState.selectedTab = .challenges
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.bottom, LayoutTokens.spacingXXL)
            }
            .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
            .refreshable {
                await viewModel.refreshDashboard()
            }
            .onAppear {
                viewModel.profile = appState.activeProfile
                Task {
                    await viewModel.reloadData()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("KLYMB")
                        .font(TypographyTokens.headline)
                        .fontWeight(.black)
                        .tracking(3)
                        .foregroundStyle(ColorTokens.textPrimary)
                }
            }
        }
    }
}

// MARK: - 1. Top Bar
private struct HomeTopBar: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        HStack(alignment: .center) {
            // Avatar & Greeting
            HStack(spacing: LayoutTokens.spacingM) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.backgroundSecondary)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle().stroke(ColorTokens.electricCyan.opacity(0.4), lineWidth: 1.5)
                        )

                    Image(systemName: "figure.run")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(ColorTokens.electricCyan)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.greetingTitle)
                        .font(TypographyTokens.caption1)
                        .fontWeight(.bold)
                        .foregroundStyle(ColorTokens.electricCyan)
                        .tracking(1)

                    Text("Let's climb today.")
                        .font(TypographyTokens.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                }
            }

            Spacer()

            // Streak Flame Badge
            StreakFlameView(streakDays: viewModel.streak.currentStreak)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.greetingTitle), \(viewModel.streak.currentStreak) day streak")
    }
}

// MARK: - 2. Hero KP Ring Card
private struct HomeHeroKPCard: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        KlymbCard(padding: LayoutTokens.paddingL) {
            VStack(spacing: LayoutTokens.spacingM) {
                // Centered Progress Ring wrapping KP Counter
                ProgressRing(
                    progress: viewModel.goalProgressRatio,
                    size: 160,
                    strokeWidth: 12
                ) {
                    VStack(spacing: 2) {
                        KPCounterView(
                            value: viewModel.todayKP,
                            font: TypographyTokens.largeTitle,
                            color: ColorTokens.textPrimary
                        )

                        Text("KP TODAY")
                            .font(TypographyTokens.caption2)
                            .fontWeight(.heavy)
                            .tracking(1.5)
                            .foregroundStyle(ColorTokens.textTertiary)

                        HStack(spacing: 3) {
                            Image(systemName: "arrowtriangle.up.fill")
                                .font(.system(size: 8))
                            Text("+\(viewModel.kpDeltaToday) KP")
                                .font(TypographyTokens.caption2.weight(.bold))
                        }
                        .foregroundStyle(ColorTokens.neonGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ColorTokens.neonGreen.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                .padding(.top, LayoutTokens.spacingS)

                // Goal summary text
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(viewModel.todayKP)")
                            .font(TypographyTokens.caption1.weight(.bold))
                            .foregroundStyle(ColorTokens.electricCyan)
                        Text("/ \(viewModel.dailyGoalKP) KP Daily Goal")
                            .font(TypographyTokens.caption1)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }

                    // Synced indicator
                    Text("Synced \(viewModel.lastSyncDescription)")
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 3. Leaderboard Overtake Nudge Card
private struct HomeOvertakeNudgeCard: View {
    let nudge: LeaderboardOvertakeNudge
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            KlymbCard(
                glowColor: ColorTokens.neonOrange.opacity(0.2),
                padding: LayoutTokens.paddingM
            ) {
                HStack(spacing: LayoutTokens.spacingM) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.neonOrange.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: "trophy.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(ColorTokens.neonOrange)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("\(nudge.cityName) #\(nudge.currentRank)")
                                .font(TypographyTokens.caption1.weight(.bold))
                                .foregroundStyle(ColorTokens.textPrimary)

                            HStack(spacing: 2) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 10, weight: .bold))
                                Text("\(nudge.rankChange)")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(ColorTokens.neonGreen)
                        }

                        Text("\(nudge.kpNeededToOvertake) KP to overtake @\(nudge.targetRivalUsername)")
                            .font(TypographyTokens.caption1)
                            .foregroundStyle(ColorTokens.neonOrange)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("City Rank #\(nudge.currentRank), \(nudge.kpNeededToOvertake) KP to overtake @\(nudge.targetRivalUsername). Tap to view leaderboards.")
    }
}

// MARK: - 4. Daily Habits Section
private struct HomeHabitsSection: View {
    let habits: [DailyHabitProgress]

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutTokens.spacingM) {
            HStack {
                Text("DAILY DISCIPLINES")
                    .font(TypographyTokens.caption1)
                    .fontWeight(.bold)
                    .tracking(1.5)
                    .foregroundStyle(ColorTokens.textTertiary)

                Spacer()

                let completedCount = habits.filter { $0.isCompleted }.count
                Text("\(completedCount)/\(habits.count) Completed")
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.electricCyan)
            }

            VStack(spacing: LayoutTokens.spacingS) {
                ForEach(habits) { habit in
                    HomeHabitRow(habit: habit)
                }
            }
        }
    }
}

private struct HomeHabitRow: View {
    let habit: DailyHabitProgress

    var body: some View {
        KlymbCard(padding: LayoutTokens.paddingM) {
            VStack(spacing: LayoutTokens.spacingS) {
                HStack(spacing: LayoutTokens.spacingM) {
                    // Habit icon
                    ZStack {
                        Circle()
                            .fill(habit.isCompleted ? ColorTokens.neonGreen.opacity(0.18) : ColorTokens.backgroundSecondary)
                            .frame(width: 38, height: 38)

                        Image(systemName: habit.iconName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(habit.isCompleted ? ColorTokens.neonGreen : ColorTokens.textPrimary)
                    }

                    // Habit title & current quantity
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.displayName)
                            .font(TypographyTokens.headline)
                            .foregroundStyle(ColorTokens.textPrimary)

                        HStack(spacing: 4) {
                            Text(habit.formattedCurrentQuantity)
                                .font(TypographyTokens.caption1.weight(.semibold))
                                .foregroundStyle(habit.isCompleted ? ColorTokens.neonGreen : ColorTokens.textSecondary)

                            Text("/ \(habit.formattedTargetQuantity)")
                                .font(TypographyTokens.caption2)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }

                    Spacer()

                    // KP Awarded
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("+\(habit.kpEarnedToday) KP")
                            .font(TypographyTokens.headline)
                            .foregroundStyle(ColorTokens.electricCyan)

                        Text("Cap: \(habit.dailyKPCap) KP")
                            .font(TypographyTokens.caption2)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }

                // Progress Bar
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(ColorTokens.backgroundSecondary)
                            .frame(height: 6)

                        Capsule()
                            .fill(habit.isCompleted ? ColorTokens.neonGreen : ColorTokens.electricCyan)
                            .frame(width: max(6, proxy.size.width * CGFloat(habit.progress)), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.displayName): \(habit.formattedCurrentQuantity) of \(habit.formattedTargetQuantity), earned \(habit.kpEarnedToday) KP.")
    }
}

// MARK: - 5. Active Challenge Banner
private struct HomeChallengeBanner: View {
    let challenge: Challenge
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            KlymbCard(
                glowColor: ColorTokens.neonPurple.opacity(0.2),
                padding: LayoutTokens.paddingM
            ) {
                HStack(spacing: LayoutTokens.spacingM) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.neonPurple.opacity(0.18))
                            .frame(width: 44, height: 44)

                        Image(systemName: "flag.checkered")
                            .font(.system(size: 20))
                            .foregroundStyle(ColorTokens.neonPurple)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("ACTIVE CHALLENGE")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(1)
                                .foregroundStyle(ColorTokens.neonPurple)

                            Text("• \(challenge.rewardKP) KP Reward")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(ColorTokens.neonYellow)
                        }

                        Text(challenge.title)
                            .font(TypographyTokens.headline)
                            .foregroundStyle(ColorTokens.textPrimary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active challenge: \(challenge.title), \(challenge.rewardKP) KP reward. Tap to view.")
    }
}
