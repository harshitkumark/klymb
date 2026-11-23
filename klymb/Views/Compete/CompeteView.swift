//
//  CompeteView.swift
//  klymb
//
//  Compete Tab: City, Global & Friends Leaderboards with Top 3 Podium,
//  Rank Change Indicators, and Pinned My-Rank Card (PRD §F10 & Design System §9.7).
//  Follows AGENTS.md Rules 2, 15, 18.
//

import SwiftUI

public struct CompeteView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: CompeteViewModel
    @State private var showFriendsSheet: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(container: AppContainerProtocol = AppContainer.mock) {
        _viewModel = StateObject(wrappedValue: CompeteViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Background
                ColorTokens.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: LayoutTokens.spacingL) {
                        // 1. Scope Selector (City / Global / Friends)
                        ScopeSegmentedBar(
                            selectedScope: viewModel.selectedScope,
                            onSelect: { viewModel.setScope($0) }
                        )
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        .padding(.top, LayoutTokens.spacingS)

                        // 2. Period Filter Chips (Daily / Weekly / All-Time)
                        PeriodFilterBar(
                            selectedPeriod: viewModel.selectedPeriod,
                            onSelect: { viewModel.setPeriod($0) }
                        )
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        if viewModel.isLoading && viewModel.entries.isEmpty {
                            ProgressView()
                                .tint(ColorTokens.electricCyan)
                                .padding(.top, 60)
                        } else if let error = viewModel.errorMessage, viewModel.entries.isEmpty {
                            VStack(spacing: LayoutTokens.spacingM) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(ColorTokens.neonRed)
                                Text(error)
                                    .font(TypographyTokens.body)
                                    .foregroundStyle(ColorTokens.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 60)
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        } else {
                            // 3. Top 3 Podium Spotlight
                            if !viewModel.topThree.isEmpty {
                                PodiumSpotlightView(
                                    podium: viewModel.topThree,
                                    onSelect: { viewModel.selectAthlete($0) }
                                )
                                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                            }

                            // 4. Leaderboard Rows (Ranks 4+)
                            if !viewModel.remainingEntries.isEmpty {
                                VStack(spacing: LayoutTokens.spacingS) {
                                    HStack {
                                        Text("CHALLENGERS")
                                            .font(TypographyTokens.caption1.bold())
                                            .foregroundStyle(ColorTokens.textTertiary)
                                        Spacer()
                                        Text("\(viewModel.entries.count) ATHLETES")
                                            .font(TypographyTokens.caption2)
                                            .foregroundStyle(ColorTokens.textTertiary)
                                    }
                                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                                    .padding(.top, LayoutTokens.spacingS)

                                    ForEach(viewModel.remainingEntries) { entry in
                                        LeaderboardRowCard(entry: entry) {
                                            viewModel.selectAthlete(entry)
                                        }
                                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                                    }
                                }
                            }
                        }

                        // Bottom Spacer for pinned bottom card
                        Spacer(minLength: 110)
                    }
                    .padding(.bottom, LayoutTokens.spacingXXL)
                }
                .refreshable {
                    await viewModel.fetchLeaderboard()
                }

                // 5. Sticky Floating Pinned "My Rank" Bar
                if let my = viewModel.myEntry {
                    PinnedMyRankBar(
                        entry: my,
                        nudgeText: viewModel.overtakeNudgeText,
                        onTap: { viewModel.selectAthlete(my) }
                    )
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    .padding(.bottom, LayoutTokens.spacingS)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Compete")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(ColorTokens.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await viewModel.fetchLeaderboard()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFriendsSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Friends")
                                .font(TypographyTokens.caption1.bold())
                        }
                        .foregroundStyle(ColorTokens.electricCyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ColorTokens.electricCyan.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .accessibilityLabel("Friends and Social")
                }
            }
            .sheet(item: $viewModel.selectedAthlete) { athlete in
                AthleteProfileSheet(athlete: athlete) {
                    viewModel.dismissAthleteProfile()
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showFriendsSheet) {
                FriendsView()
            }
        }
    }
}

// MARK: - 1. Scope Segmented Bar
private struct ScopeSegmentedBar: View {
    let selectedScope: LeaderboardScope
    let onSelect: (LeaderboardScope) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(LeaderboardScope.allCases) { scope in
                let isSelected = (scope == selectedScope)

                Button {
                    onSelect(scope)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: scope.iconName)
                            .font(.system(size: 13, weight: .semibold))
                        Text(scope.title)
                            .font(TypographyTokens.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isSelected ? ColorTokens.backgroundTertiary : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusM))
                    .overlay(
                        RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                            .strokeBorder(isSelected ? ColorTokens.electricCyan.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
                    .foregroundStyle(isSelected ? ColorTokens.electricCyan : ColorTokens.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(scope.title) Leaderboard")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(ColorTokens.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusL))
    }
}

// MARK: - 2. Period Filter Bar
private struct PeriodFilterBar: View {
    let selectedPeriod: LeaderboardPeriod
    let onSelect: (LeaderboardPeriod) -> Void

    var body: some View {
        HStack(spacing: LayoutTokens.spacingS) {
            ForEach(LeaderboardPeriod.allCases) { period in
                let isSelected = (period == selectedPeriod)

                Button {
                    onSelect(period)
                } label: {
                    Text(period.title)
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
                .accessibilityLabel("\(period.title) timeframe")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }

            Spacer()
        }
    }
}

// MARK: - 3. Podium Spotlight View
private struct PodiumSpotlightView: View {
    let podium: [LeaderboardEntry]
    let onSelect: (LeaderboardEntry) -> Void

    private var first: LeaderboardEntry? { podium.first(where: { $0.rank == 1 }) }
    private var second: LeaderboardEntry? { podium.first(where: { $0.rank == 2 }) }
    private var third: LeaderboardEntry? { podium.first(where: { $0.rank == 3 }) }

    var body: some View {
        VStack(spacing: LayoutTokens.spacingM) {
            HStack(alignment: .bottom, spacing: LayoutTokens.spacingS) {
                // Rank 2: Silver (Left)
                if let entry = second {
                    PodiumColumn(
                        entry: entry,
                        pedestalHeight: 92,
                        pedestalColor: Color.KlymbRank.silver,
                        avatarSize: 56,
                        onTap: { onSelect(entry) }
                    )
                }

                // Rank 1: Gold (Center)
                if let entry = first {
                    PodiumColumn(
                        entry: entry,
                        pedestalHeight: 124,
                        pedestalColor: Color.KlymbRank.gold,
                        avatarSize: 68,
                        isFirst: true,
                        onTap: { onSelect(entry) }
                    )
                }

                // Rank 3: Bronze (Right)
                if let entry = third {
                    PodiumColumn(
                        entry: entry,
                        pedestalHeight: 76,
                        pedestalColor: Color.KlymbRank.bronze,
                        avatarSize: 52,
                        onTap: { onSelect(entry) }
                    )
                }
            }
        }
        .padding(.vertical, LayoutTokens.paddingM)
        .padding(.horizontal, LayoutTokens.paddingS)
        .background(
            RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                .fill(ColorTokens.backgroundSecondary.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                .strokeBorder(ColorTokens.borderSubtle, lineWidth: 1)
        )
    }
}

private struct PodiumColumn: View {
    let entry: LeaderboardEntry
    let pedestalHeight: CGFloat
    let pedestalColor: Color
    let avatarSize: CGFloat
    var isFirst: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 6) {
                // Crown / Medal Icon
                if isFirst {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.KlymbRank.gold)
                        .shadow(color: Color.KlymbRank.gold.opacity(0.5), radius: 6)
                }

                // Avatar with Rank Border
                ZStack {
                    Circle()
                        .fill(ColorTokens.backgroundTertiary)
                        .frame(width: avatarSize, height: avatarSize)

                    Image(systemName: entry.avatarIconName)
                        .font(.system(size: avatarSize * 0.44))
                        .foregroundStyle(pedestalColor)

                    // Small rank badge overlay
                    Text("\(entry.rank)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(pedestalColor)
                        .clipShape(Capsule())
                        .offset(y: avatarSize / 2 - 2)
                }
                .overlay(
                    Circle()
                        .strokeBorder(pedestalColor.opacity(isFirst ? 0.9 : 0.6), lineWidth: isFirst ? 2.5 : 1.5)
                )

                // Athlete Name
                Text(entry.displayName ?? entry.username)
                    .font(TypographyTokens.caption1.bold())
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: 96)
                    .padding(.top, 4)

                // Total KP
                Text("\(entry.totalKP) KP")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(isFirst ? ColorTokens.electricCyan : ColorTokens.textSecondary)

                // Rank Change Chip
                RankChangeBadge(change: entry.rankChange)

                // Pedestal Block
                RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                    .fill(
                        LinearGradient(
                            colors: [pedestalColor.opacity(0.25), pedestalColor.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                            .strokeBorder(pedestalColor.opacity(0.4), lineWidth: 1)
                    )
                    .frame(height: pedestalHeight)
                    .overlay(
                        VStack {
                            Text("#\(entry.rank)")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundStyle(pedestalColor)
                                .padding(.top, LayoutTokens.spacingS)
                            Spacer()
                        }
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank), \(entry.displayName ?? entry.username), \(entry.totalKP) KP")
    }
}

// MARK: - 4. Leaderboard Row Card
private struct LeaderboardRowCard: View {
    let entry: LeaderboardEntry
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: LayoutTokens.spacingM) {
                // Rank number
                Text(String(format: "%02d", entry.rank))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(entry.rankColor)
                    .frame(width: 28, alignment: .leading)

                // Avatar Icon
                ZStack {
                    Circle()
                        .fill(ColorTokens.backgroundSecondary)
                        .frame(width: 40, height: 40)

                    Image(systemName: entry.avatarIconName)
                        .font(.system(size: 18))
                        .foregroundStyle(entry.isCurrentUser ? ColorTokens.electricCyan : ColorTokens.textSecondary)
                }
                .overlay(
                    Circle()
                        .strokeBorder(entry.isCurrentUser ? ColorTokens.electricCyan : Color.clear, lineWidth: 1.5)
                )

                // Names & optional City
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.displayName ?? entry.username)
                            .font(TypographyTokens.subheadline.bold())
                            .foregroundStyle(ColorTokens.textPrimary)
                            .lineLimit(1)

                        if entry.isCurrentUser {
                            Text("YOU")
                                .font(.system(size: 9, weight: .black))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(ColorTokens.electricCyan.opacity(0.2))
                                .foregroundStyle(ColorTokens.electricCyan)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 6) {
                        Text("@\(entry.username)")
                            .font(TypographyTokens.caption2)
                            .foregroundStyle(ColorTokens.textTertiary)

                        if let city = entry.cityName {
                            Text("•")
                                .font(TypographyTokens.caption2)
                                .foregroundStyle(ColorTokens.textTertiary)
                            Text(city)
                                .font(TypographyTokens.caption2)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                    }
                }

                Spacer()

                // Rank Change Badge
                RankChangeBadge(change: entry.rankChange)

                // KP Amount
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.totalKP)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(entry.isCurrentUser ? ColorTokens.electricCyan : ColorTokens.textPrimary)
                    Text("KP")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .frame(minWidth: 54, alignment: .trailing)
            }
            .padding(.horizontal, LayoutTokens.paddingM)
            .padding(.vertical, LayoutTokens.paddingS)
            .background(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                    .fill(entry.isCurrentUser ? ColorTokens.backgroundTertiary : ColorTokens.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                    .strokeBorder(
                        entry.isCurrentUser ? ColorTokens.electricCyan.opacity(0.6) : ColorTokens.borderSubtle,
                        lineWidth: entry.isCurrentUser ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank), \(entry.displayName ?? entry.username), \(entry.totalKP) KP, rank change \(entry.rankChange)")
    }
}

// MARK: - 5. Pinned My Rank Bar
private struct PinnedMyRankBar: View {
    let entry: LeaderboardEntry
    let nudgeText: String?
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: LayoutTokens.spacingS) {
                HStack(spacing: LayoutTokens.spacingM) {
                    // Rank badge
                    HStack(spacing: 4) {
                        Image(systemName: "number")
                            .font(.system(size: 12, weight: .bold))
                        Text("\(entry.rank)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(ColorTokens.electricCyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ColorTokens.electricCyan.opacity(0.15))
                    .clipShape(Capsule())

                    // Avatar & user info
                    ZStack {
                        Circle()
                            .fill(ColorTokens.backgroundTertiary)
                            .frame(width: 36, height: 36)
                        Image(systemName: entry.avatarIconName)
                            .font(.system(size: 16))
                            .foregroundStyle(ColorTokens.electricCyan)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(entry.displayName ?? entry.username)
                                .font(TypographyTokens.subheadline.bold())
                                .foregroundStyle(ColorTokens.textPrimary)
                            Text("(YOU)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(ColorTokens.electricCyan)
                        }
                        Text("@\(entry.username)")
                            .font(TypographyTokens.caption2)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }

                    Spacer()

                    // Rank Change
                    RankChangeBadge(change: entry.rankChange)

                    // KP total
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(entry.totalKP)")
                            .font(.system(size: 16, weight: .heavy, design: .monospaced))
                            .foregroundStyle(ColorTokens.electricCyan)
                        Text("TOTAL KP")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }

                // Overtake Nudge Line
                if let nudge = nudgeText {
                    Divider()
                        .background(ColorTokens.borderSubtle)

                    HStack(spacing: 6) {
                        Text(nudge)
                            .font(TypographyTokens.caption1.weight(.semibold))
                            .foregroundStyle(ColorTokens.electricCyan)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }
            .padding(.horizontal, LayoutTokens.paddingM)
            .padding(.vertical, LayoutTokens.paddingM)
            .background(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                    .fill(ColorTokens.backgroundTertiary)
                    .shadow(color: Color.black.opacity(0.6), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                    .strokeBorder(ColorTokens.electricCyan.opacity(0.8), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your Standing: Rank \(entry.rank), \(entry.totalKP) KP. \(nudgeText ?? "")")
    }
}

// MARK: - Rank Change Indicator
private struct RankChangeBadge: View {
    let change: Int

    var body: some View {
        HStack(spacing: 2) {
            if change > 0 {
                Image(systemName: "arrow.up")
                    .font(.system(size: 9, weight: .black))
                Text("\(change)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            } else if change < 0 {
                Image(systemName: "arrow.down")
                    .font(.system(size: 9, weight: .black))
                Text("\(abs(change))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            } else {
                Text("—")
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .foregroundStyle(changeColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(changeColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var changeColor: Color {
        if change > 0 { return ColorTokens.neonGreen }
        if change < 0 { return ColorTokens.neonRed }
        return ColorTokens.textTertiary
    }
}

// MARK: - Athlete Public Profile Sheet
private struct AthleteProfileSheet: View {
    let athlete: LeaderboardEntry
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: LayoutTokens.spacingL) {
                // Large Avatar
                ZStack {
                    Circle()
                        .fill(ColorTokens.backgroundSecondary)
                        .frame(width: 88, height: 88)

                    Image(systemName: athlete.avatarIconName)
                        .font(.system(size: 40))
                        .foregroundStyle(athlete.rankColor)
                }
                .overlay(
                    Circle()
                        .strokeBorder(athlete.rankColor.opacity(0.8), lineWidth: 2.5)
                )
                .padding(.top, LayoutTokens.spacingM)

                // Names & City
                VStack(spacing: 4) {
                    Text(athlete.displayName ?? athlete.username)
                        .font(TypographyTokens.title2)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("@\(athlete.username)")
                        .font(TypographyTokens.subheadline)
                        .foregroundStyle(ColorTokens.textTertiary)

                    if let city = athlete.cityName {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 12))
                            Text(city)
                        }
                        .font(TypographyTokens.caption1)
                        .foregroundStyle(ColorTokens.electricCyan)
                        .padding(.top, 4)
                    }
                }

                // Stats Grid
                HStack(spacing: LayoutTokens.spacingM) {
                    StatTile(
                        icon: "trophy.fill",
                        value: "#\(athlete.rank)",
                        label: "RANK",
                        valueColor: athlete.rankColor
                    )

                    StatTile(
                        icon: "flame.fill",
                        value: "\(athlete.totalKP)",
                        label: "TOTAL KP",
                        valueColor: ColorTokens.electricCyan
                    )

                    StatTile(
                        icon: athlete.rankChange >= 0 ? "arrow.up.right" : "arrow.down.right",
                        value: athlete.rankChange >= 0 ? "+\(athlete.rankChange)" : "\(athlete.rankChange)",
                        label: "TREND",
                        valueColor: athlete.rankChange >= 0 ? ColorTokens.neonGreen : ColorTokens.neonRed
                    )
                }
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                // Badges / Accolades Preview
                VStack(alignment: .leading, spacing: LayoutTokens.spacingS) {
                    Text("SHOWCASED BADGES")
                        .font(TypographyTokens.caption1.bold())
                        .foregroundStyle(ColorTokens.textTertiary)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    HStack(spacing: LayoutTokens.spacingM) {
                        BadgeIcon(icon: "flame.fill", title: "7d Streak", color: ColorTokens.neonOrange)
                        BadgeIcon(icon: "bolt.fill", title: "Century Run", color: ColorTokens.electricCyan)
                        BadgeIcon(icon: "crown.fill", title: "Top 10", color: Color.KlymbRank.gold)
                    }
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                }

                Spacer()

                // Action Button
                PrimaryButton(
                    athlete.isCurrentUser ? "Done" : "Cheer Athlete",
                    icon: athlete.isCurrentUser ? "checkmark" : "hands.clap.fill",
                    action: {
                        HapticManager.celebration()
                        onClose()
                    }
                )
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                .padding(.bottom, LayoutTokens.spacingM)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Athlete Profile")
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

private struct BadgeIcon: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                    .fill(ColorTokens.backgroundSecondary)
                    .frame(width: 54, height: 54)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
            }
            .overlay(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CompeteView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
