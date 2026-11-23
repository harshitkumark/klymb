//
//  ChallengesView.swift
//  klymb
//
//  Challenges Tab: Daily, Weekly & Community Quests with Live Progress,
//  KP Rewards, and Detail Sheet (PRD §F12 & Design System §9.8).
//  Follows AGENTS.md Rules 2, 15, 18.
//

import SwiftUI

public struct ChallengesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ChallengesViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(container: AppContainerProtocol = AppContainer.mock) {
        _viewModel = StateObject(wrappedValue: ChallengesViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LayoutTokens.spacingL) {
                    // 1. Quests Header Summary
                    ChallengesHeaderBanner(
                        joinedCount: viewModel.joinedChallengesCount,
                        potentialKP: viewModel.potentialRewardKP
                    )
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    .padding(.top, LayoutTokens.spacingS)

                    // 2. Category Filter Pills
                    ChallengeCategoryFilterBar(
                        selectedCategory: viewModel.selectedCategory,
                        onSelect: { viewModel.setCategory($0) }
                    )
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    // 3. Challenge Cards List
                    if viewModel.isLoading && viewModel.challenges.isEmpty {
                        ProgressView()
                            .tint(ColorTokens.electricCyan)
                            .padding(.top, 40)
                    } else if let error = viewModel.errorMessage, viewModel.challenges.isEmpty {
                        VStack(spacing: LayoutTokens.spacingM) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(ColorTokens.neonRed)
                            Text(error)
                                .font(TypographyTokens.body)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                        .padding(.top, 40)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    } else if viewModel.filteredChallenges.isEmpty {
                        EmptyChallengesView(category: viewModel.selectedCategory)
                            .padding(.top, 40)
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    } else {
                        VStack(spacing: LayoutTokens.spacingM) {
                            ForEach(viewModel.filteredChallenges) { challenge in
                                ChallengeCard(challenge: challenge) {
                                    viewModel.selectChallenge(challenge)
                                }
                                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.bottom, LayoutTokens.spacingXXL)
            }
            .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(ColorTokens.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .refreshable {
                await viewModel.fetchChallenges()
            }
            .task {
                await viewModel.fetchChallenges()
            }
            .sheet(item: $viewModel.selectedChallenge) { challenge in
                ChallengeDetailSheet(
                    challenge: challenge,
                    standings: viewModel.standings,
                    isLoading: viewModel.isActionLoading,
                    onToggleJoin: {
                        Task {
                            await viewModel.toggleJoin(for: challenge)
                        }
                    },
                    onClose: {
                        viewModel.dismissDetail()
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - 1. Challenges Header Banner
private struct ChallengesHeaderBanner: View {
    let joinedCount: Int
    let potentialKP: Int

    var body: some View {
        HStack(spacing: LayoutTokens.spacingM) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIVE QUESTS")
                    .font(TypographyTokens.caption1.bold())
                    .foregroundStyle(ColorTokens.electricCyan)

                Text("\(joinedCount) Joined")
                    .font(TypographyTokens.title2)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Complete goals before time expires")
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("REWARD POOL")
                    .font(TypographyTokens.caption1.bold())
                    .foregroundStyle(Color.KlymbRank.gold)

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.KlymbRank.gold)
                    Text("+\(potentialKP)")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(ColorTokens.textPrimary)
                }

                Text("KP Available")
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .padding(LayoutTokens.paddingL)
        .background(
            RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                .fill(ColorTokens.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                .strokeBorder(ColorTokens.electricCyan.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(joinedCount) active challenges joined. \(potentialKP) KP available to earn.")
    }
}

// MARK: - 2. Category Filter Bar
private struct ChallengeCategoryFilterBar: View {
    let selectedCategory: ChallengeCategoryFilter
    let onSelect: (ChallengeCategoryFilter) -> Void

    var body: some View {
        HStack(spacing: LayoutTokens.spacingS) {
            ForEach(ChallengeCategoryFilter.allCases) { category in
                let isSelected = (category == selectedCategory)

                Button {
                    onSelect(category)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: category.iconName)
                            .font(.system(size: 12, weight: .bold))
                        Text(category.title)
                            .font(TypographyTokens.caption1.weight(.semibold))
                    }
                    .padding(.horizontal, LayoutTokens.paddingM)
                    .padding(.vertical, 8)
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
                .accessibilityLabel("\(category.title) category")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }

            Spacer()
        }
    }
}

// MARK: - 3. Challenge Card
private struct ChallengeCard: View {
    let challenge: Challenge
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: LayoutTokens.spacingM) {
                // Top Tag & Reward Row
                HStack(spacing: LayoutTokens.spacingS) {
                    // Habit icon
                    ZStack {
                        RoundedRectangle(cornerRadius: LayoutTokens.radiusS)
                            .fill(challenge.categoryColor.opacity(0.2))
                            .frame(width: 36, height: 36)

                        Image(systemName: challenge.habitIconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(challenge.categoryColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(challenge.type.uppercased())
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(challenge.categoryColor)

                            Text("•")
                                .font(TypographyTokens.caption2)
                                .foregroundStyle(ColorTokens.textTertiary)

                            Text(challenge.timeRemainingText)
                                .font(TypographyTokens.caption2)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }

                        Text(challenge.title)
                            .font(TypographyTokens.headline)
                            .foregroundStyle(ColorTokens.textPrimary)
                    }

                    Spacer()

                    // Reward badge
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 11))
                        Text("+\(challenge.rewardKP) KP")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(Color.KlymbRank.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.KlymbRank.gold.opacity(0.12))
                    .clipShape(Capsule())
                }

                if let desc = challenge.description {
                    Text(desc)
                        .font(TypographyTokens.caption1)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .lineLimit(2)
                }

                // Progress Bar & Target
                VStack(spacing: 6) {
                    HStack {
                        Text(challenge.isCompleted ? "COMPLETED" : (challenge.isJoined ? "IN PROGRESS" : "AVAILABLE"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(challenge.isCompleted ? ColorTokens.neonGreen : (challenge.isJoined ? ColorTokens.electricCyan : ColorTokens.textTertiary))

                        Spacer()

                        Text("\(challenge.formattedCurrent) / \(challenge.formattedTarget)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(ColorTokens.textPrimary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ColorTokens.backgroundTertiary)
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: challenge.isCompleted ? [ColorTokens.neonGreen, ColorTokens.electricCyan] : [challenge.categoryColor, ColorTokens.electricCyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(challenge.progressRatio), height: 8)
                        }
                    }
                    .frame(height: 8)
                }

                // Bottom Status Pill
                HStack {
                    if challenge.isJoined {
                        HStack(spacing: 4) {
                            Image(systemName: challenge.isCompleted ? "checkmark.circle.fill" : "bolt.circle.fill")
                                .font(.system(size: 12))
                            Text(challenge.isCompleted ? "Goal Reached" : "Joined & Tracking")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(challenge.isCompleted ? ColorTokens.neonGreen : ColorTokens.electricCyan)
                    } else {
                        Text("Tap to view details & join")
                            .font(TypographyTokens.caption2)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .padding(LayoutTokens.paddingM)
            .background(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                    .fill(ColorTokens.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                    .strokeBorder(
                        challenge.isJoined ? challenge.categoryColor.opacity(0.5) : ColorTokens.borderSubtle,
                        lineWidth: challenge.isJoined ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(challenge.title), \(challenge.type), \(Int(challenge.progressRatio * 100)) percent complete, reward \(challenge.rewardKP) KP, \(challenge.timeRemainingText)")
    }
}

// MARK: - 4. Challenge Detail Sheet
private struct ChallengeDetailSheet: View {
    let challenge: Challenge
    let standings: [LeaderboardEntry]
    let isLoading: Bool
    let onToggleJoin: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LayoutTokens.spacingL) {
                    // Top Hero Icon
                    ZStack {
                        Circle()
                            .fill(challenge.categoryColor.opacity(0.18))
                            .frame(width: 80, height: 80)

                        Image(systemName: challenge.habitIconName)
                            .font(.system(size: 36))
                            .foregroundStyle(challenge.categoryColor)
                    }
                    .overlay(
                        Circle()
                            .strokeBorder(challenge.categoryColor.opacity(0.6), lineWidth: 2)
                    )
                    .padding(.top, LayoutTokens.spacingM)

                    // Title & Description
                    VStack(spacing: 6) {
                        Text(challenge.type.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(challenge.categoryColor)

                        Text(challenge.title)
                            .font(TypographyTokens.title2)
                            .foregroundStyle(ColorTokens.textPrimary)
                            .multilineTextAlignment(.center)

                        if let desc = challenge.description {
                            Text(desc)
                                .font(TypographyTokens.body)
                                .foregroundStyle(ColorTokens.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        }
                    }

                    // Key Metrics Grid
                    HStack(spacing: LayoutTokens.spacingM) {
                        StatTile(
                            icon: "target",
                            value: challenge.formattedTarget,
                            label: "GOAL",
                            valueColor: challenge.categoryColor
                        )

                        StatTile(
                            icon: "trophy.fill",
                            value: "+\(challenge.rewardKP) KP",
                            label: "REWARD",
                            valueColor: Color.KlymbRank.gold
                        )

                        StatTile(
                            icon: "clock.fill",
                            value: challenge.timeRemainingText,
                            label: "CLOSES IN",
                            valueColor: ColorTokens.neonOrange
                        )
                    }
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    // Progress Section
                    VStack(alignment: .leading, spacing: LayoutTokens.spacingS) {
                        HStack {
                            Text("YOUR PROGRESS")
                                .font(TypographyTokens.caption1.bold())
                                .foregroundStyle(ColorTokens.textTertiary)
                            Spacer()
                            Text("\(challenge.formattedCurrent) / \(challenge.formattedTarget)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(ColorTokens.electricCyan)
                        }

                        ProgressView(value: challenge.progressRatio)
                            .tint(challenge.categoryColor)
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    // Challenge Standings / Participants
                    if !standings.isEmpty {
                        VStack(alignment: .leading, spacing: LayoutTokens.spacingS) {
                            Text("TOP PARTICIPANTS")
                                .font(TypographyTokens.caption1.bold())
                                .foregroundStyle(ColorTokens.textTertiary)

                            ForEach(standings) { athlete in
                                HStack(spacing: LayoutTokens.spacingM) {
                                    Text("#\(athlete.rank)")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundStyle(athlete.rankColor)
                                        .frame(width: 28, alignment: .leading)

                                    Image(systemName: athlete.avatarIconName)
                                        .foregroundStyle(ColorTokens.electricCyan)

                                    Text(athlete.displayName ?? athlete.username)
                                        .font(TypographyTokens.subheadline.bold())
                                        .foregroundStyle(ColorTokens.textPrimary)

                                    Spacer()

                                    Text("\(athlete.totalKP) KP")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(ColorTokens.textSecondary)
                                }
                                .padding(LayoutTokens.paddingM)
                                .background(
                                    RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                                        .fill(ColorTokens.backgroundSecondary)
                                )
                            }
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    }

                    Spacer(minLength: 20)

                    // Action Button
                    if challenge.isJoined {
                        SecondaryButton(
                            "Leave Challenge",
                            icon: "xmark.circle",
                            action: onToggleJoin
                        )
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    } else {
                        PrimaryButton(
                            "Join Challenge",
                            icon: "plus.circle.fill",
                            isLoading: isLoading,
                            action: onToggleJoin
                        )
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    }
                }
                .padding(.bottom, LayoutTokens.spacingL)
            }
            .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Challenge Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onClose)
                        .foregroundStyle(ColorTokens.electricCyan)
                }
            }
        }
    }
}

// MARK: - 5. Empty State
private struct EmptyChallengesView: View {
    let category: ChallengeCategoryFilter

    var body: some View {
        VStack(spacing: LayoutTokens.spacingM) {
            Image(systemName: "flag.slash.fill")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.textTertiary)

            Text("No \(category.title) Challenges")
                .font(TypographyTokens.headline)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("Check back soon for new community quests and daily discipline goals.")
                .font(TypographyTokens.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    ChallengesView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
