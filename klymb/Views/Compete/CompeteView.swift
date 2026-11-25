//
//  CompeteView.swift
//  klymb
//
//  Compete Tab: City, Global & Friends Leaderboards with metallic-rimmed Top 3 stage,
//  grouped challenger table, frosted My Standing dock, and athlete sheet.
//

import SwiftUI

public struct CompeteView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: CompeteViewModel
    @State private var showFriendsSheet: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let container: AppContainerProtocol

    public init(container: AppContainerProtocol = AppContainer.mock) {
        self.container = container
        _viewModel = StateObject(wrappedValue: CompeteViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.KlymbBackground.primary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: KlymbSpacing.lg) {
                        // 1. Header + Friends Pill
                        HStack(alignment: .center) {
                            Text("Compete")
                                .font(Font.Klymb.titleLarge)
                                .foregroundStyle(Color.KlymbText.primary)

                            Spacer()

                            Button {
                                showFriendsSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.KlymbAccent.soft)
                                    Text("Friends")
                                        .font(Font.Klymb.caption.weight(.semibold))
                                        .foregroundStyle(Color.KlymbText.primary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .klymbCardStyle(cornerRadius: KlymbRadius.full, isElevated: true)
                            }
                            .buttonStyle(KlymbPressableButtonStyle())
                            .accessibilityLabel("Friends and Social")
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        .padding(.top, KlymbSpacing.sm)

                        // 2. Scope Segmented Control (City / Global / Friends)
                        KlymbSegmentedControl(
                            options: LeaderboardScope.allCases,
                            selection: Binding(
                                get: { viewModel.selectedScope },
                                set: { viewModel.setScope($0) }
                            ),
                            title: { $0.title },
                            onSelect: { viewModel.setScope($0) }
                        )
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        // 3. Minimal Underlined Period Filter Strip
                        PeriodUnderlineBar(
                            selectedPeriod: viewModel.selectedPeriod,
                            onSelect: { viewModel.setPeriod($0) }
                        )
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        if viewModel.isLoading && viewModel.entries.isEmpty {
                            ProgressView()
                                .tint(Color.KlymbAccent.primary)
                                .padding(.top, 60)
                        } else if let error = viewModel.errorMessage, viewModel.entries.isEmpty {
                            VStack(spacing: KlymbSpacing.md) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Color.KlymbSemantic.error)
                                Text(error)
                                    .font(Font.Klymb.body)
                                    .foregroundStyle(Color.KlymbText.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 60)
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        } else {
                            // 4. Architectural Top 3 Stage
                            if !viewModel.topThree.isEmpty {
                                PodiumStageView(
                                    podium: viewModel.topThree,
                                    onSelect: { viewModel.selectAthlete($0) }
                                )
                                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                            }

                            // 5. Grouped Ranked Leaderboard Table (#4+)
                            if !viewModel.remainingEntries.isEmpty {
                                VStack(alignment: .leading, spacing: KlymbSpacing.sm) {
                                    KlymbSectionHeader(
                                        "Challengers",
                                        trailingText: "\(viewModel.entries.count) ATHLETES",
                                        trailingColor: Color.KlymbText.tertiary
                                    )

                                    KlymbGroupedSurface(cornerRadius: KlymbRadius.lg) {
                                        ForEach(Array(viewModel.remainingEntries.enumerated()), id: \.element.id) { index, entry in
                                            if index > 0 {
                                                Divider()
                                                    .background(Color.KlymbBorder.subtle)
                                                    .padding(.leading, 48)
                                            }
                                            LeaderboardTableRow(entry: entry) {
                                                viewModel.selectAthlete(entry)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.bottom, KlymbSpacing.xl)
                }
                .refreshable {
                    await viewModel.fetchLeaderboard()
                }

                // 6. Sticky Frosted Glass My Standing Dock
                if let my = viewModel.myEntry {
                    PinnedMyRankBar(
                        entry: my,
                        nudgeText: viewModel.overtakeNudgeText,
                        onTap: { viewModel.selectAthlete(my) }
                    )
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    .padding(.bottom, KlymbSpacing.sm)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.fetchLeaderboard()
            }
            .sheet(item: $viewModel.selectedAthlete) { athlete in
                AthleteProfileSheet(
                    athlete: athlete,
                    onCheer: {
                        Task {
                            try? await container.socialService.cheerFriend(targetUserId: athlete.userId)
                        }
                    },
                    onClose: {
                        viewModel.dismissAthleteProfile()
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showFriendsSheet) {
                FriendsView(container: container)
            }
        }
    }
}

// MARK: - Period Underline Filter
private struct PeriodUnderlineBar: View {
    let selectedPeriod: LeaderboardPeriod
    let onSelect: (LeaderboardPeriod) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: KlymbSpacing.xl) {
                ForEach(LeaderboardPeriod.allCases) { period in
                    let isSelected = (period == selectedPeriod)

                    Button {
                        onSelect(period)
                    } label: {
                        VStack(spacing: 8) {
                            Text(period.title)
                                .font(Font.Klymb.bodySmall.weight(.semibold))
                                .foregroundStyle(isSelected ? Color.KlymbAccent.soft : Color.KlymbText.secondary)

                            Rectangle()
                                .fill(isSelected ? Color.KlymbAccent.primary : Color.clear)
                                .frame(height: 2)
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(period.title) timeframe")
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
                Spacer()
            }

            Divider().background(Color.KlymbBorder.subtle)
        }
    }
}

// MARK: - Top 3 Architectural Stage
private struct PodiumStageView: View {
    let podium: [LeaderboardEntry]
    let onSelect: (LeaderboardEntry) -> Void

    private var first: LeaderboardEntry? { podium.first(where: { $0.rank == 1 }) }
    private var second: LeaderboardEntry? { podium.first(where: { $0.rank == 2 }) }
    private var third: LeaderboardEntry? { podium.first(where: { $0.rank == 3 }) }

    var body: some View {
        HStack(alignment: .bottom, spacing: KlymbSpacing.sm) {
            if let entry = second {
                PodiumSlotCard(
                    entry: entry,
                    accentColor: Color.KlymbRank.silver,
                    avatarSize: 46,
                    isFirst: false,
                    onTap: { onSelect(entry) }
                )
            }

            if let entry = first {
                PodiumSlotCard(
                    entry: entry,
                    accentColor: Color.KlymbAccent.soft,
                    avatarSize: 54,
                    isFirst: true,
                    onTap: { onSelect(entry) }
                )
            }

            if let entry = third {
                PodiumSlotCard(
                    entry: entry,
                    accentColor: Color.KlymbRank.bronze,
                    avatarSize: 44,
                    isFirst: false,
                    onTap: { onSelect(entry) }
                )
            }
        }
    }
}

private struct PodiumSlotCard: View {
    let entry: LeaderboardEntry
    let accentColor: Color
    let avatarSize: CGFloat
    let isFirst: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: KlymbSpacing.sm) {
                ZStack(alignment: .bottom) {
                    Circle()
                        .fill(isFirst ? Color.KlymbAccent.primaryMuted : Color.KlymbBackground.tertiary)
                        .frame(width: avatarSize, height: avatarSize)
                        .overlay(
                            Image(systemName: entry.avatarIconName)
                                .font(.system(size: avatarSize * 0.42, weight: .semibold))
                                .foregroundStyle(accentColor)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(accentColor.opacity(isFirst ? 0.85 : 0.6), lineWidth: isFirst ? 2 : 1.5)
                        )

                    Text("\(entry.rank)")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.KlymbText.inverse)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accentColor)
                        .clipShape(Capsule())
                        .offset(y: 6)
                }
                .padding(.bottom, 6)

                VStack(spacing: 2) {
                    Text(entry.displayName ?? entry.username)
                        .font(Font.Klymb.caption.weight(.semibold))
                        .foregroundStyle(Color.KlymbText.primary)
                        .lineLimit(1)

                    Text("\(entry.totalKP.formatted()) KP")
                        .font(Font.Klymb.telemetry)
                        .monospacedDigit()
                        .foregroundStyle(isFirst ? Color.KlymbAccent.soft : Color.KlymbText.secondary)
                }

                RankChangeBadge(change: entry.rankChange)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, isFirst ? 16 : 12)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isFirst {
                        LinearGradient(
                            colors: [Color.KlymbAccent.primary.opacity(0.14), Color.KlymbBackground.secondary],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        Color.KlymbBackground.secondary
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous)
                    .strokeBorder(
                        isFirst ? Color.KlymbAccent.primary.opacity(0.45) : Color.KlymbBorder.default,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(KlymbPressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank), \(entry.displayName ?? entry.username), \(entry.totalKP) KP")
    }
}

// MARK: - Grouped Leaderboard Row
private struct LeaderboardTableRow: View {
    let entry: LeaderboardEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .leading) {
                HStack(spacing: KlymbSpacing.md) {
                    Text(String(format: "%02d", entry.rank))
                        .font(Font.Klymb.rankNumber)
                        .monospacedDigit()
                        .foregroundStyle(entry.isCurrentUser ? Color.KlymbAccent.soft : Color.KlymbText.tertiary)
                        .frame(width: 28, alignment: .leading)

                    ZStack {
                        Circle()
                            .fill(entry.isCurrentUser ? Color.KlymbAccent.primaryMuted : Color.KlymbBackground.tertiary)
                            .frame(width: 36, height: 36)

                        Image(systemName: entry.avatarIconName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(entry.isCurrentUser ? Color.KlymbAccent.soft : Color.KlymbText.secondary)
                    }
                    .overlay(
                        Circle()
                            .strokeBorder(entry.isCurrentUser ? Color.KlymbAccent.primary.opacity(0.6) : Color.clear, lineWidth: 1.5)
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(entry.displayName ?? entry.username)
                                .font(Font.Klymb.bodySmall.weight(.semibold))
                                .foregroundStyle(Color.KlymbText.primary)
                                .lineLimit(1)

                            if entry.isCurrentUser {
                                Text("YOU")
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(Color.KlymbText.inverse)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.KlymbAccent.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                            }
                        }

                        HStack(spacing: 5) {
                            Text("@\(entry.username)")
                                .font(Font.Klymb.captionSmall)
                                .foregroundStyle(Color.KlymbText.tertiary)

                            if let city = entry.cityName {
                                Text("• \(city)")
                                    .font(Font.Klymb.captionSmall)
                                    .foregroundStyle(Color.KlymbText.secondary)
                            }
                        }
                    }

                    Spacer()

                    RankChangeBadge(change: entry.rankChange)

                    Text("\(entry.totalKP.formatted())")
                        .font(Font.Klymb.kpInline)
                        .monospacedDigit()
                        .foregroundStyle(entry.isCurrentUser ? Color.KlymbAccent.soft : Color.KlymbText.primary)
                        .frame(minWidth: 48, alignment: .trailing)
                }
                .padding(.horizontal, KlymbSpacing.lg)
                .padding(.vertical, 12)

                if entry.isCurrentUser {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.KlymbAccent.primary)
                        .frame(width: 3)
                        .padding(.vertical, 8)
                }
            }
            .background(entry.isCurrentUser ? Color.KlymbAccent.primaryMuted : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(entry.rank), \(entry.displayName ?? entry.username), \(entry.totalKP) KP, rank change \(entry.rankChange)")
    }
}

// MARK: - Sticky Frosted Glass Standing Dock
private struct PinnedMyRankBar: View {
    let entry: LeaderboardEntry
    let nudgeText: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: KlymbSpacing.md) {
                Text("#\(entry.rank)")
                    .font(Font.Klymb.rankNumber)
                    .monospacedDigit()
                    .foregroundStyle(Color.KlymbAccent.soft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.KlymbAccent.primaryMuted)
                    .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(nudgeText ?? (entry.displayName ?? "@\(entry.username)"))
                        .font(Font.Klymb.caption.weight(.semibold))
                        .foregroundStyle(Color.KlymbText.primary)
                        .lineLimit(1)

                    Text("@\(entry.username)\(entry.cityName.map { " • \($0)" } ?? "")")
                        .font(Font.Klymb.captionSmall)
                        .foregroundStyle(Color.KlymbText.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(entry.totalKP.formatted())")
                        .font(Font.Klymb.kpInline)
                        .monospacedDigit()
                        .foregroundStyle(Color.KlymbAccent.soft)
                    Text("KP")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.KlymbText.tertiary)
                }
            }
            .padding(.horizontal, KlymbSpacing.md)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial)
            .background(Color.KlymbBackground.elevated.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous)
                    .strokeBorder(Color.KlymbAccent.primary.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 14, y: 6)
        }
        .buttonStyle(KlymbPressableButtonStyle())
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
                    .font(.system(size: 9, weight: .bold))
                Text("\(change)")
                    .font(Font.Klymb.telemetry)
            } else if change < 0 {
                Image(systemName: "arrow.down")
                    .font(.system(size: 9, weight: .bold))
                Text("\(abs(change))")
                    .font(Font.Klymb.telemetry)
            } else {
                Text("—")
                    .font(Font.Klymb.telemetry)
            }
        }
        .foregroundStyle(changeColor)
    }

    private var changeColor: Color {
        if change > 0 { return Color.KlymbSemantic.success }
        if change < 0 { return Color.KlymbSemantic.error }
        return Color.KlymbText.tertiary
    }
}

// MARK: - Athlete Public Profile Sheet
private struct AthleteProfileSheet: View {
    let athlete: LeaderboardEntry
    let onCheer: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: KlymbSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(Color.KlymbBackground.tertiary)
                        .frame(width: 84, height: 84)

                    Image(systemName: athlete.avatarIconName)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(athlete.rankColor)
                }
                .overlay(
                    Circle()
                        .strokeBorder(athlete.rankColor.opacity(0.75), lineWidth: 2)
                )
                .padding(.top, KlymbSpacing.md)

                VStack(spacing: 4) {
                    Text(athlete.displayName ?? athlete.username)
                        .font(Font.Klymb.titleSmall)
                        .foregroundStyle(Color.KlymbText.primary)

                    Text("@\(athlete.username)")
                        .font(Font.Klymb.bodySmall)
                        .foregroundStyle(Color.KlymbText.tertiary)

                    if let city = athlete.cityName {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 12))
                            Text(city)
                        }
                        .font(Font.Klymb.caption)
                        .foregroundStyle(Color.KlymbAccent.soft)
                        .padding(.top, 2)
                    }
                }

                HStack(spacing: KlymbSpacing.md) {
                    StatTile(
                        icon: "trophy.fill",
                        value: "#\(athlete.rank)",
                        label: "Rank",
                        valueColor: athlete.rankColor
                    )

                    StatTile(
                        icon: "flame.fill",
                        value: "\(athlete.totalKP.formatted())",
                        label: "Total KP",
                        valueColor: Color.KlymbAccent.soft
                    )

                    StatTile(
                        icon: athlete.rankChange >= 0 ? "arrow.up.right" : "arrow.down.right",
                        value: athlete.rankChange >= 0 ? "+\(athlete.rankChange)" : "\(athlete.rankChange)",
                        label: "Trend",
                        valueColor: athlete.rankChange >= 0 ? Color.KlymbSemantic.success : Color.KlymbSemantic.error
                    )
                }
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                VStack(alignment: .leading, spacing: KlymbSpacing.sm) {
                    KlymbSectionHeader("Showcased Badges")
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    HStack(spacing: KlymbSpacing.md) {
                        BadgeIcon(icon: "flame.fill", title: "7d Streak", color: Color.KlymbAccent.primary)
                        BadgeIcon(icon: "bolt.fill", title: "Century Run", color: Color.KlymbAccent.soft)
                        BadgeIcon(icon: "crown.fill", title: "Top 10", color: Color.KlymbRank.gold)
                    }
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                }

                Spacer()

                PrimaryButton(
                    athlete.isCurrentUser ? "Done" : "Cheer Athlete",
                    icon: athlete.isCurrentUser ? "checkmark" : "hands.clap.fill",
                    tone: .bone,
                    action: {
                        if !athlete.isCurrentUser {
                            onCheer()
                        }
                        HapticManager.celebration()
                        onClose()
                    }
                )
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                .padding(.bottom, KlymbSpacing.md)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.KlymbBackground.primary.ignoresSafeArea())
            .navigationTitle("Athlete Profile")
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

private struct BadgeIcon: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous)
                    .fill(Color.KlymbBackground.secondary)
                    .frame(width: 52, height: 52)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
            }
            .overlay(
                RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )

            Text(title)
                .font(Font.Klymb.captionSmall.weight(.medium))
                .foregroundStyle(Color.KlymbText.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CompeteView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
