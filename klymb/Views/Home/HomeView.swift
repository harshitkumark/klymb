//
//  HomeView.swift
//  klymb
//
//  Home dashboard cockpit: open sports-instrument KP dial, thermal effort states,
//  split telemetry, rival chase strip, grouped daily disciplines, and active quest.
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
            ZStack(alignment: .top) {
                Color.KlymbBackground.primary.ignoresSafeArea()

                // Subtle thermal radial ambient spotlight behind the dial
                RadialGradient(
                    colors: [
                        (viewModel.goalProgressRatio >= 1.0 ? Color.KlymbSemantic.success : Color.KlymbAccent.primary)
                            .opacity(viewModel.todayKP > 0 ? 0.08 : 0.03),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.18),
                    startRadius: 16,
                    endRadius: 240
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: KlymbSpacing.lg) {
                        // 1. Unified Clean Top Header
                        HomeTopBar(viewModel: viewModel) {
                            appState.selectedTab = .profile
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        .padding(.top, KlymbSpacing.sm)

                        // 2. Open Telemetry KP Dial & Split Strip
                        HomeHeroCockpit(viewModel: viewModel) {
                            appState.selectedTab = .compete
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        // 3. Near-Miss Rival Chase Strip
                        if let nudge = viewModel.overtakeNudge {
                            HomeOvertakeNudgeCard(nudge: nudge) {
                                appState.selectedTab = .compete
                            }
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        }

                        // 4. Unified Grouped Daily Disciplines
                        HomeHabitsSection(habits: viewModel.habitProgresses)
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        // 5. Active Challenge Strip
                        if let challenge = viewModel.activeChallenge {
                            HomeChallengeBanner(challenge: challenge) {
                                appState.selectedTab = .challenges
                            }
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        }

                        Spacer(minLength: KlymbSpacing.xl)
                    }
                    .padding(.bottom, KlymbSpacing.xl)
                }
                .refreshable {
                    await viewModel.refreshDashboard()
                }
            }
            .onAppear {
                viewModel.profile = appState.activeProfile
                Task {
                    await viewModel.reloadData()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - 1. Top Header
private struct HomeTopBar: View {
    @ObservedObject var viewModel: HomeViewModel
    let onTapAvatar: () -> Void

    private var arenaLabel: String {
        let city = viewModel.profile?.cityName ?? "Klymb Arena"
        return "\(city.uppercased()) • TODAY"
    }

    private var personalGreeting: String {
        guard let profile = viewModel.profile else { return "Let's climb today." }
        if let name = profile.displayName, !name.trimmingCharacters(in: .whitespaces).isEmpty {
            let first = name.components(separatedBy: " ").first ?? name
            return "Hey, \(first)"
        }
        return "@\(profile.username)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: KlymbSpacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                Text(arenaLabel)
                    .font(Font.Klymb.telemetry)
                    .tracking(1.1)
                    .foregroundStyle(Color.KlymbText.secondary)
                    .lineLimit(1)

                Text(personalGreeting)
                    .font(Font.Klymb.titleSmall)
                    .foregroundStyle(Color.KlymbText.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text("Let's climb today.")
                    .font(Font.Klymb.caption)
                    .foregroundStyle(Color.KlymbText.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: KlymbSpacing.sm)

            HStack(spacing: KlymbSpacing.sm) {
                StreakFlameView(streakDays: viewModel.streak.currentStreak)

                Button(action: onTapAvatar) {
                    ZStack {
                        Circle()
                            .fill(Color.KlymbBackground.secondary)
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle()
                                    .strokeBorder(KlymbGradient.specularBorder, lineWidth: 1)
                            )

                        Image(systemName: KlymbIconCatalog.avatarIcon(for: viewModel.profile?.avatarPreset))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.KlymbAccent.soft)
                    }
                }
                .buttonStyle(KlymbPressableButtonStyle())
                .accessibilityLabel("Open profile")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.greetingTitle), Let's climb today, \(viewModel.streak.currentStreak) day streak")
    }
}

// MARK: - 2. Open Telemetry KP Dial & Split Strip
private struct HomeHeroCockpit: View {
    @ObservedObject var viewModel: HomeViewModel
    let onTapRank: () -> Void

    private var isGoalHit: Bool {
        viewModel.goalProgressRatio >= 1.0
    }

    private var deltaText: String {
        if isGoalHit {
            return "GOAL HIT • +\(viewModel.kpDeltaToday)"
        } else if viewModel.kpDeltaToday > 0 {
            return "+\(viewModel.kpDeltaToday) TODAY"
        } else {
            return "READY TO CLIMB"
        }
    }

    var body: some View {
        VStack(spacing: KlymbSpacing.md) {
            ProgressRing(
                progress: viewModel.goalProgressRatio,
                size: 196,
                strokeWidth: 7,
                openGauge: true,
                showTicks: true
            ) {
                VStack(spacing: 4) {
                    Text("KP TODAY")
                        .font(Font.Klymb.telemetry)
                        .tracking(1.6)
                        .foregroundStyle(Color.KlymbText.secondary)

                    KPCounterView(
                        value: viewModel.todayKP,
                        font: .system(size: 46, weight: .heavy).width(.condensed),
                        color: Color.KlymbText.primary
                    )

                    HStack(spacing: 3) {
                        Image(systemName: isGoalHit ? "checkmark" : (viewModel.kpDeltaToday > 0 ? "arrowtriangle.up.fill" : "flame"))
                            .font(.system(size: 8, weight: .bold))
                        Text(deltaText)
                            .font(Font.Klymb.telemetry)
                    }
                    .foregroundStyle(
                        isGoalHit
                            ? Color.KlymbSemantic.success
                            : (viewModel.kpDeltaToday > 0 ? Color.KlymbAccent.soft : Color.KlymbText.tertiary)
                    )
                    .padding(.top, 2)
                }
                .padding(.top, 14)
            }

            // 3-Column Unified Split Telemetry Strip
            KlymbGroupedSurface(cornerRadius: KlymbRadius.lg) {
                HStack(spacing: 0) {
                    TelemetryCell(
                        label: "Daily Goal",
                        value: "\(Int(min(viewModel.goalProgressRatio, 9.99) * 100))%",
                        sublabel: "\(viewModel.todayKP)/\(viewModel.dailyGoalKP)",
                        valueColor: isGoalHit ? Color.KlymbSemantic.success : Color.KlymbText.primary
                    )

                    VerticalHairline()

                    Button(action: onTapRank) {
                        TelemetryCell(
                            label: "City Rank",
                            value: viewModel.overtakeNudge.map { "#\($0.currentRank)" } ?? "Ranked",
                            sublabel: viewModel.overtakeNudge.map { $0.cityName } ?? "Tap to view",
                            valueColor: Color.KlymbAccent.soft
                        )
                    }
                    .buttonStyle(.plain)

                    VerticalHairline()

                    TelemetryCell(
                        label: "Last Sync",
                        value: viewModel.lastSyncDescription == "Not synced yet" ? "Pending" : viewModel.lastSyncDescription,
                        sublabel: "HealthKit",
                        valueColor: Color.KlymbText.primary
                    )
                }
                .padding(.vertical, 11)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's KP: \(viewModel.todayKP) out of \(viewModel.dailyGoalKP) KP daily goal, plus \(viewModel.kpDeltaToday) KP today. Synced \(viewModel.lastSyncDescription).")
    }
}

private struct TelemetryCell: View {
    let label: String
    let value: String
    let sublabel: String
    let valueColor: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(Font.Klymb.captionSmall)
                .foregroundStyle(Color.KlymbText.secondary)
                .lineLimit(1)

            Text(value)
                .font(Font.Klymb.kpInline)
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(sublabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.KlymbText.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}

private struct VerticalHairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.KlymbBorder.subtle)
            .frame(width: 1, height: 32)
    }
}

// MARK: - 3. Near-Miss Rival Chase Card
private struct HomeOvertakeNudgeCard: View {
    let nudge: LeaderboardOvertakeNudge
    let action: () -> Void

    private var proximityProgress: Double {
        let ratio = 1.0 - (Double(min(nudge.kpNeededToOvertake, 250)) / 250.0)
        return max(0.18, min(0.92, ratio))
    }

    var body: some View {
        Button(action: action) {
            KlymbCard(padding: KlymbSpacing.md, isElevated: true) {
                VStack(spacing: KlymbSpacing.sm) {
                    HStack(spacing: KlymbSpacing.sm) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.KlymbAccent.soft)

                        Text("Pass @\(nudge.targetRivalUsername) for #\(max(1, nudge.currentRank - 1))")
                            .font(Font.Klymb.bodySmall.weight(.semibold))
                            .foregroundStyle(Color.KlymbText.primary)
                            .lineLimit(1)

                        Spacer()

                        Text("\(nudge.kpNeededToOvertake) KP LEFT")
                            .font(Font.Klymb.telemetry)
                            .foregroundStyle(Color.KlymbAccent.soft)
                            .monospacedDigit()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.KlymbText.tertiary)
                    }

                    KlymbProgressBar(
                        progress: proximityProgress,
                        height: 5,
                        fillOverride: KlymbGradient.fire
                    )
                }
            }
        }
        .buttonStyle(KlymbPressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("City Rank #\(nudge.currentRank), \(nudge.kpNeededToOvertake) KP to overtake @\(nudge.targetRivalUsername). Tap to view leaderboards.")
    }
}

// MARK: - 4. Grouped Daily Disciplines
private struct HomeHabitsSection: View {
    let habits: [DailyHabitProgress]

    private var completedCount: Int {
        habits.filter { $0.isCompleted }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KlymbSpacing.sm) {
            KlymbSectionHeader(
                "Daily Disciplines",
                trailingText: "\(completedCount)/\(habits.count) COMPLETE",
                trailingColor: (completedCount == habits.count && !habits.isEmpty)
                    ? Color.KlymbSemantic.success
                    : Color.KlymbAccent.soft
            )

            KlymbGroupedSurface(cornerRadius: KlymbRadius.lg) {
                if habits.isEmpty {
                    Text("Pull down to sync your selected daily habits.")
                        .font(Font.Klymb.bodySmall)
                        .foregroundStyle(Color.KlymbText.secondary)
                        .padding(KlymbSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                        if index > 0 {
                            Divider()
                                .background(Color.KlymbBorder.subtle)
                                .padding(.leading, KlymbSpacing.lg)
                        }
                        HomeHabitRow(habit: habit)
                    }
                }
            }
        }
    }
}

private struct HomeHabitRow: View {
    let habit: DailyHabitProgress

    private var statusColor: Color {
        if habit.isCompleted { return Color.KlymbSemantic.success }
        if habit.currentQuantity > 0 { return Color.KlymbAccent.primary }
        return Color.KlymbText.tertiary
    }

    private var kpTextColor: Color {
        if habit.isCompleted { return Color.KlymbSemantic.success }
        if habit.kpEarnedToday > 0 { return Color.KlymbAccent.soft }
        return Color.KlymbText.tertiary
    }

    var body: some View {
        VStack(spacing: KlymbSpacing.sm) {
            HStack(spacing: KlymbSpacing.sm) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                Image(systemName: habit.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(habit.isCompleted ? Color.KlymbSemantic.success : Color.KlymbText.secondary)
                    .frame(width: 20)

                Text(habit.displayName)
                    .font(Font.Klymb.headline)
                    .foregroundStyle(Color.KlymbText.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: KlymbSpacing.sm) {
                    Text("\(habit.formattedCurrentQuantity) / \(habit.formattedTargetQuantity)")
                        .font(Font.Klymb.caption)
                        .foregroundStyle(Color.KlymbText.secondary)
                        .monospacedDigit()

                    Text("+\(habit.kpEarnedToday)")
                        .font(Font.Klymb.kpInline)
                        .foregroundStyle(kpTextColor)
                        .frame(minWidth: 36, alignment: .trailing)
                }
            }

            KlymbProgressBar(
                progress: habit.progress,
                height: 3,
                isCompleted: habit.isCompleted
            )
        }
        .padding(.horizontal, KlymbSpacing.lg)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.displayName): \(habit.formattedCurrentQuantity) of \(habit.formattedTargetQuantity), earned \(habit.kpEarnedToday) KP.")
    }
}

// MARK: - 5. Active Challenge Strip
private struct HomeChallengeBanner: View {
    let challenge: Challenge
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            KlymbCard(padding: KlymbSpacing.md) {
                VStack(spacing: KlymbSpacing.sm) {
                    HStack(spacing: KlymbSpacing.md) {
                        Image(systemName: challenge.habitIconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.KlymbAccent.soft)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("ACTIVE QUEST")
                                    .font(Font.Klymb.telemetry)
                                    .foregroundStyle(Color.KlymbAccent.soft)

                                Text("+\(challenge.rewardKP) KP")
                                    .font(Font.Klymb.telemetry)
                                    .foregroundStyle(Color.KlymbText.secondary)
                            }

                            Text(challenge.title)
                                .font(Font.Klymb.headline)
                                .foregroundStyle(Color.KlymbText.primary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text("\(Int(challenge.progressRatio * 100))%")
                            .font(Font.Klymb.telemetry)
                            .foregroundStyle(challenge.isCompleted ? Color.KlymbSemantic.success : Color.KlymbText.secondary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.KlymbText.tertiary)
                    }

                    KlymbProgressBar(
                        progress: challenge.progressRatio,
                        height: 3,
                        isCompleted: challenge.isCompleted
                    )
                }
            }
        }
        .buttonStyle(KlymbPressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active challenge: \(challenge.title), \(challenge.rewardKP) KP reward. Tap to view.")
    }
}
