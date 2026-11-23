//
//  NotificationPreferencesView.swift
//  klymb
//
//  Push notification settings & granular preference toggles (PRD §F14 & Design System §9.11).
//  Follows AGENTS.md Rules 15, 18.
//

import SwiftUI
import UserNotifications

public struct NotificationPreferencesView: View {
    @ObservedObject var manager: NotificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LayoutTokens.spacingL) {
                    // 1. Permission Status Banner
                    PermissionStatusCard(manager: manager)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        .padding(.top, LayoutTokens.spacingS)

                    // 2. Granular Toggles Section
                    VStack(alignment: .leading, spacing: LayoutTokens.spacingM) {
                        Text("NOTIFICATION PREFERENCES")
                            .font(TypographyTokens.caption1.bold())
                            .foregroundStyle(ColorTokens.textTertiary)
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        VStack(spacing: 0) {
                            PreferenceToggleRow(
                                icon: "trophy.fill",
                                iconColor: Color.KlymbRank.gold,
                                title: "Overtake Alerts",
                                subtitle: "Get notified when a rival passes your rank on the leaderboard",
                                isOn: Binding(
                                    get: { manager.preferences.overtaken },
                                    set: { val in
                                        Task {
                                            await manager.updatePreferences(overtaken: val)
                                        }
                                    }
                                )
                            )

                            Divider()
                                .background(ColorTokens.borderSubtle)
                                .padding(.leading, 56)

                            PreferenceToggleRow(
                                icon: "flame.fill",
                                iconColor: ColorTokens.neonOrange,
                                title: "Streak at Risk Warnings",
                                subtitle: "Remind you at 8:00 PM if daily disciplines are incomplete",
                                isOn: Binding(
                                    get: { manager.preferences.streakRisk },
                                    set: { val in
                                        Task {
                                            await manager.updatePreferences(streakRisk: val)
                                            manager.scheduleStreakReminder()
                                        }
                                    }
                                )
                            )

                            Divider()
                                .background(ColorTokens.borderSubtle)
                                .padding(.leading, 56)

                            PreferenceToggleRow(
                                icon: "flag.checkered",
                                iconColor: ColorTokens.neonPurple,
                                title: "Challenge Closing Reminders",
                                subtitle: "Alerts 2 hours before daily & weekly challenges conclude",
                                isOn: Binding(
                                    get: { manager.preferences.challengeEnding },
                                    set: { val in
                                        Task {
                                            await manager.updatePreferences(challengeEnding: val)
                                        }
                                    }
                                )
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                                .fill(ColorTokens.backgroundSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                                .strokeBorder(ColorTokens.borderSubtle, lineWidth: 1)
                        )
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    }

                    // 3. Test Simulation Section
                    VStack(alignment: .leading, spacing: LayoutTokens.spacingS) {
                        Text("SIMULATED NOTIFICATIONS")
                            .font(TypographyTokens.caption1.bold())
                            .foregroundStyle(ColorTokens.textTertiary)
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        Button {
                            manager.routeNotification(userInfo: [
                                "type": "overtake",
                                "title": "⚡️ You were overtaken!",
                                "body": "@speedy_runner passed you on the San Francisco leaderboard."
                            ])
                            dismiss()
                        } label: {
                            HStack(spacing: LayoutTokens.spacingM) {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(ColorTokens.electricCyan)
                                Text("Test Overtake Alert (Routes to Compete)")
                                    .font(TypographyTokens.subheadline.bold())
                                    .foregroundStyle(ColorTokens.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                            .padding(LayoutTokens.paddingM)
                            .background(
                                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                                    .fill(ColorTokens.backgroundSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                                    .strokeBorder(ColorTokens.electricCyan.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.bottom, LayoutTokens.spacingXXL)
            }
            .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ColorTokens.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(ColorTokens.electricCyan)
                }
            }
        }
    }
}

// MARK: - 1. Permission Status Card
private struct PermissionStatusCard: View {
    @ObservedObject var manager: NotificationManager

    private var isAuthorized: Bool {
        manager.authorizationStatus == .authorized
    }

    var body: some View {
        VStack(spacing: LayoutTokens.spacingM) {
            HStack(spacing: LayoutTokens.spacingM) {
                ZStack {
                    Circle()
                        .fill(isAuthorized ? ColorTokens.neonGreen.opacity(0.15) : ColorTokens.neonOrange.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: isAuthorized ? "bell.badge.fill" : "bell.slash.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(isAuthorized ? ColorTokens.neonGreen : ColorTokens.neonOrange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(isAuthorized ? "Notifications Enabled" : "Notifications Disabled")
                        .font(TypographyTokens.headline)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text(isAuthorized ? "You will receive real-time rank updates" : "Enable notifications to protect your streak")
                        .font(TypographyTokens.caption1)
                        .foregroundStyle(ColorTokens.textSecondary)
                }

                Spacer()
            }

            if !isAuthorized {
                PrimaryButton("Enable Notifications", icon: "bell.fill") {
                    Task {
                        _ = await manager.requestAuthorization()
                    }
                }
            }
        }
        .padding(LayoutTokens.paddingL)
        .background(
            RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                .fill(ColorTokens.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                .strokeBorder(
                    isAuthorized ? ColorTokens.neonGreen.opacity(0.3) : ColorTokens.neonOrange.opacity(0.4),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - 2. Preference Toggle Row
private struct PreferenceToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: LayoutTokens.spacingM) {
            ZStack {
                RoundedRectangle(cornerRadius: LayoutTokens.radiusS)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TypographyTokens.subheadline.bold())
                    .foregroundStyle(ColorTokens.textPrimary)

                Text(subtitle)
                    .font(TypographyTokens.caption2)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(ColorTokens.electricCyan)
        }
        .padding(LayoutTokens.paddingM)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(isOn ? "enabled" : "disabled")")
    }
}

#Preview {
    NotificationPreferencesView()
        .preferredColorScheme(.dark)
}
