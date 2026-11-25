//
//  ChallengesView.swift
//  klymb
//
//  Challenges Tab: Daily, Weekly & Community Quests with Thermal Effort hierarchy,
//  crisp vector progress bars, and interactive detail sheet.
//

import SwiftUI

public struct ChallengesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ChallengesViewModel

    public init(container: AppContainerProtocol = AppContainer.mock) {
        _viewModel = StateObject(wrappedValue: ChallengesViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.KlymbBackground.primary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: KlymbSpacing.lg) {
                        // 1. Editorial Header
                        HStack(alignment: .lastTextBaseline) {
                            Text("Challenges")
                                .font(Font.Klymb.titleLarge)
                                .foregroundStyle(Color.KlymbText.primary)

                            Spacer()

                            Text("+\(viewModel.potentialRewardKP) KP POOL")
                                .font(Font.Klymb.telemetry)
                                .foregroundStyle(Color.KlymbAccent.soft)
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        .padding(.top, KlymbSpacing.sm)

                        // 2. Compact Summary Strip
                        ChallengesSummaryStrip(
                            joinedCount: viewModel.joinedChallengesCount,
                            potentialKP: viewModel.potentialRewardKP
                        )
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        // 3. Underlined Category Filter
                        ChallengeCategoryUnderlineBar(
                            selectedCategory: viewModel.selectedCategory,
                            onSelect: { viewModel.setCategory($0) }
                        )
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        // 4. Challenge List
                        if viewModel.isLoading && viewModel.challenges.isEmpty {
                            ProgressView()
                                .tint(Color.KlymbAccent.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 48)
                        } else if let error = viewModel.errorMessage, viewModel.challenges.isEmpty {
                            VStack(spacing: KlymbSpacing.md) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.KlymbSemantic.error)
                                Text(error)
                                    .font(Font.Klymb.body)
                                    .foregroundStyle(Color.KlymbText.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        } else if viewModel.filteredChallenges.isEmpty {
                            EmptyChallengesView(category: viewModel.selectedCategory)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 48)
                                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        } else {
                            VStack(spacing: KlymbSpacing.md) {
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
                    .padding(.bottom, KlymbSpacing.xl)
                }
                .refreshable {
                    await viewModel.fetchChallenges()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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

// MARK: - Summary Strip
private struct ChallengesSummaryStrip: View {
    let joinedCount: Int
    let potentialKP: Int

    var body: some View {
        KlymbCard(padding: KlymbSpacing.lg, isElevated: true) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ACTIVE QUESTS")
                        .font(Font.Klymb.telemetry)
                        .foregroundStyle(Color.KlymbText.secondary)

                    Text("\(joinedCount) Joined")
                        .font(Font.Klymb.athleticMetric)
                        .foregroundStyle(Color.KlymbText.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(Color.KlymbBorder.subtle)
                    .frame(width: 1, height: 34)
                    .padding(.horizontal, KlymbSpacing.md)

                VStack(alignment: .leading, spacing: 3) {
                    Text("AVAILABLE REWARD")
                        .font(Font.Klymb.telemetry)
                        .foregroundStyle(Color.KlymbText.secondary)

                    Text("+\(potentialKP.formatted()) KP")
                        .font(Font.Klymb.athleticMetric)
                        .foregroundStyle(Color.KlymbAccent.soft)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(joinedCount) active challenges joined. \(potentialKP) KP available to earn.")
    }
}

// MARK: - Underlined Category Strip
private struct ChallengeCategoryUnderlineBar: View {
    let selectedCategory: ChallengeCategoryFilter
    let onSelect: (ChallengeCategoryFilter) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: KlymbSpacing.xl) {
                    ForEach(ChallengeCategoryFilter.allCases) { category in
                        let isSelected = (category == selectedCategory)

                        Button {
                            onSelect(category)
                        } label: {
                            VStack(spacing: 8) {
                                Text(category.title)
                                    .font(Font.Klymb.bodySmall.weight(.semibold))
                                    .foregroundStyle(isSelected ? Color.KlymbAccent.soft : Color.KlymbText.secondary)

                                Rectangle()
                                    .fill(isSelected ? Color.KlymbAccent.primary : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(category.title) category")
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }
            }
            Divider().background(Color.KlymbBorder.subtle)
        }
    }
}

// MARK: - Challenge Card
private struct ChallengeCard: View {
    let challenge: Challenge
    let onTap: () -> Void

    private var statusColor: Color {
        if challenge.isCompleted { return Color.KlymbSemantic.success }
        if challenge.isJoined { return Color.KlymbAccent.soft }
        return Color.KlymbText.tertiary
    }

    var body: some View {
        Button(action: onTap) {
            KlymbCard(
                glowColor: challenge.isCompleted ? Color.KlymbSemantic.success : (challenge.isJoined ? Color.KlymbAccent.primary : nil),
                padding: KlymbSpacing.lg,
                isElevated: !challenge.isCompleted
            ) {
                VStack(alignment: .leading, spacing: KlymbSpacing.md) {
                    HStack(alignment: .top, spacing: KlymbSpacing.md) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Image(systemName: challenge.habitIconName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(challenge.isCompleted ? Color.KlymbSemantic.success : Color.KlymbAccent.soft)

                                Text(challenge.type.uppercased())
                                    .font(Font.Klymb.telemetry)
                                    .foregroundStyle(challenge.isCompleted ? Color.KlymbSemantic.success : Color.KlymbAccent.soft)

                                Text("• \(challenge.timeRemainingText)")
                                    .font(Font.Klymb.captionSmall)
                                    .foregroundStyle(Color.KlymbText.tertiary)
                            }

                            Text(challenge.title)
                                .font(Font.Klymb.headline)
                                .foregroundStyle(Color.KlymbText.primary)

                            if let desc = challenge.description {
                                Text(desc)
                                    .font(Font.Klymb.caption)
                                    .foregroundStyle(Color.KlymbText.secondary)
                                    .lineLimit(2)
                                    .padding(.top, 2)
                            }
                        }

                        Spacer(minLength: KlymbSpacing.sm)

                        Text("+\(challenge.rewardKP) KP")
                            .font(Font.Klymb.telemetry)
                            .monospacedDigit()
                            .foregroundStyle(challenge.isCompleted ? Color.KlymbSemantic.success : Color.KlymbAccent.soft)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                (challenge.isCompleted ? Color.KlymbSemantic.success : Color.KlymbAccent.primary)
                                    .opacity(0.14)
                            )
                            .clipShape(Capsule())
                    }

                    VStack(spacing: 6) {
                        HStack {
                            Text(challenge.isCompleted ? "GOAL HIT" : (challenge.isJoined ? "IN PROGRESS" : "AVAILABLE"))
                                .font(Font.Klymb.telemetry)
                                .foregroundStyle(statusColor)

                            Spacer()

                            Text("\(challenge.formattedCurrent) / \(challenge.formattedTarget)")
                                .font(Font.Klymb.telemetry)
                                .monospacedDigit()
                                .foregroundStyle(Color.KlymbText.primary)
                        }

                        KlymbProgressBar(
                            progress: challenge.progressRatio,
                            height: 5,
                            isCompleted: challenge.isCompleted
                        )
                    }
                }
            }
        }
        .buttonStyle(KlymbPressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(challenge.title), \(challenge.type), \(Int(challenge.progressRatio * 100)) percent complete, reward \(challenge.rewardKP) KP, \(challenge.timeRemainingText)")
    }
}

// MARK: - Challenge Detail Sheet
private struct ChallengeDetailSheet: View {
    let challenge: Challenge
    let standings: [LeaderboardEntry]
    let isLoading: Bool
    let onToggleJoin: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KlymbSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(Color.KlymbAccent.primaryMuted)
                            .frame(width: 76, height: 76)

                        Image(systemName: challenge.habitIconName)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Color.KlymbAccent.soft)
                    }
                    .overlay(
                        Circle()
                            .strokeBorder(Color.KlymbAccent.primary.opacity(0.45), lineWidth: 1.5)
                    )
                    .padding(.top, KlymbSpacing.md)

                    VStack(spacing: 6) {
                        Text(challenge.type.uppercased())
                            .font(Font.Klymb.telemetry)
                            .foregroundStyle(Color.KlymbAccent.soft)

                        Text(challenge.title)
                            .font(Font.Klymb.titleSmall)
                            .foregroundStyle(Color.KlymbText.primary)
                            .multilineTextAlignment(.center)

                        if let desc = challenge.description {
                            Text(desc)
                                .font(Font.Klymb.bodySmall)
                                .foregroundStyle(Color.KlymbText.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        }
                    }

                    HStack(spacing: KlymbSpacing.md) {
                        StatTile(
                            icon: "target",
                            value: challenge.formattedTarget,
                            label: "Goal",
                            valueColor: Color.KlymbAccent.soft
                        )

                        StatTile(
                            icon: "trophy.fill",
                            value: "+\(challenge.rewardKP)",
                            label: "Reward KP",
                            valueColor: Color.KlymbRank.gold
                        )

                        StatTile(
                            icon: "clock.fill",
                            value: challenge.timeRemainingText,
                            label: "Remaining",
                            valueColor: Color.KlymbText.primary
                        )
                    }
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    VStack(alignment: .leading, spacing: KlymbSpacing.sm) {
                        HStack {
                            Text("YOUR PROGRESS")
                                .font(Font.Klymb.telemetry)
                                .foregroundStyle(Color.KlymbText.secondary)
                            Spacer()
                            Text("\(challenge.formattedCurrent) / \(challenge.formattedTarget)")
                                .font(Font.Klymb.telemetry)
                                .monospacedDigit()
                                .foregroundStyle(challenge.isCompleted ? Color.KlymbSemantic.success : Color.KlymbAccent.soft)
                        }

                        KlymbProgressBar(
                            progress: challenge.progressRatio,
                            height: 6,
                            isCompleted: challenge.isCompleted
                        )
                    }
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    if !standings.isEmpty {
                        VStack(alignment: .leading, spacing: KlymbSpacing.sm) {
                            KlymbSectionHeader("Top Participants")

                            KlymbGroupedSurface {
                                ForEach(Array(standings.enumerated()), id: \.element.id) { index, athlete in
                                    if index > 0 {
                                        Divider().background(Color.KlymbBorder.subtle)
                                    }
                                    HStack(spacing: KlymbSpacing.md) {
                                        Text("#\(athlete.rank)")
                                            .font(Font.Klymb.rankNumber)
                                            .foregroundStyle(athlete.rankColor)
                                            .frame(width: 30, alignment: .leading)

                                        Image(systemName: athlete.avatarIconName)
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.KlymbAccent.soft)

                                        Text(athlete.displayName ?? athlete.username)
                                            .font(Font.Klymb.bodySmall.weight(.semibold))
                                            .foregroundStyle(Color.KlymbText.primary)

                                        Spacer()

                                        Text("\(athlete.totalKP.formatted()) KP")
                                            .font(Font.Klymb.telemetry)
                                            .monospacedDigit()
                                            .foregroundStyle(Color.KlymbText.secondary)
                                    }
                                    .padding(.horizontal, KlymbSpacing.lg)
                                    .padding(.vertical, 12)
                                }
                            }
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    }

                    Spacer(minLength: 16)

                    if challenge.isJoined {
                        SecondaryButton(
                            "Leave Challenge",
                            icon: "xmark",
                            action: onToggleJoin
                        )
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    } else {
                        PrimaryButton(
                            "Join Challenge",
                            icon: "plus",
                            isLoading: isLoading,
                            action: onToggleJoin
                        )
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    }
                }
                .padding(.bottom, KlymbSpacing.lg)
            }
            .background(Color.KlymbBackground.primary.ignoresSafeArea())
            .navigationTitle("Challenge Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onClose)
                        .foregroundStyle(Color.KlymbAccent.soft)
                }
            }
        }
    }
}

private struct EmptyChallengesView: View {
    let category: ChallengeCategoryFilter

    var body: some View {
        VStack(spacing: KlymbSpacing.md) {
            Image(systemName: "flag.slash")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.KlymbText.tertiary)

            Text("No \(category.title) Challenges")
                .font(Font.Klymb.headline)
                .foregroundStyle(Color.KlymbText.primary)

            Text("Check back soon for new daily and weekly discipline quests.")
                .font(Font.Klymb.bodySmall)
                .foregroundStyle(Color.KlymbText.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    ChallengesView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
