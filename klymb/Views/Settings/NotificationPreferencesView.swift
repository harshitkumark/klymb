//
//  NotificationPreferencesView.swift
//  klymb
//
//  Push notification settings & granular preference toggles inside unified grouped containers.
//

import SwiftUI
import UserNotifications

public struct NotificationPreferencesView: View {
    @ObservedObject var manager: NotificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: KlymbSpacing.lg) {
                    PermissionStatusCard(manager: manager)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        .padding(.top, KlymbSpacing.sm)

                    VStack(alignment: .leading, spacing: KlymbSpacing.sm) {
                        KlymbSectionHeader("Notification Preferences")
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        KlymbGroupedSurface {
                            PreferenceToggleRow(
                                icon: "trophy.fill",
                                iconColor: Color.KlymbRank.gold,
                                title: "Overtake Alerts",
                                subtitle: "Notify when a rival passes your rank on the leaderboard",
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
                                .background(Color.KlymbBorder.subtle)
                                .padding(.leading, 48)

                            PreferenceToggleRow(
                                icon: "flame.fill",
                                iconColor: Color.KlymbAccent.primary,
                                title: "Streak at Risk Warnings",
                                subtitle: "Remind at 8:00 PM if daily disciplines are incomplete",
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
                                .background(Color.KlymbBorder.subtle)
                                .padding(.leading, 48)

                            PreferenceToggleRow(
                                icon: "flag.checkered",
                                iconColor: Color.KlymbAccent.soft,
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
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    }

                    VStack(alignment: .leading, spacing: KlymbSpacing.sm) {
                        KlymbSectionHeader("Simulated Notifications")
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        Button {
                            manager.routeNotification(userInfo: [
                                "type": "overtake",
                                "title": "You were overtaken!",
                                "body": "@speedy_runner passed you on the San Francisco leaderboard."
                            ])
                            dismiss()
                        } label: {
                            KlymbCard(padding: KlymbSpacing.lg) {
                                HStack(spacing: KlymbSpacing.md) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.KlymbAccent.soft)

                                    Text("Test Overtake Alert (Routes to Compete)")
                                        .font(Font.Klymb.bodySmall.weight(.semibold))
                                        .foregroundStyle(Color.KlymbText.primary)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.KlymbText.tertiary)
                                }
                            }
                        }
                        .buttonStyle(KlymbPressableButtonStyle())
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.bottom, KlymbSpacing.xl)
            }
            .background(Color.KlymbBackground.primary.ignoresSafeArea())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.KlymbBackground.primary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.KlymbAccent.soft)
                }
            }
        }
    }
}

private struct PermissionStatusCard: View {
    @ObservedObject var manager: NotificationManager

    private var isAuthorized: Bool {
        manager.authorizationStatus == .authorized
    }

    var body: some View {
        KlymbCard(
            glowColor: isAuthorized ? Color.KlymbSemantic.success : Color.KlymbSemantic.warning,
            padding: KlymbSpacing.lg,
            isElevated: true
        ) {
            VStack(spacing: KlymbSpacing.md) {
                HStack(spacing: KlymbSpacing.md) {
                    Image(systemName: isAuthorized ? "bell.badge.fill" : "bell.slash.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isAuthorized ? Color.KlymbSemantic.success : Color.KlymbSemantic.warning)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isAuthorized ? "Notifications Enabled" : "Notifications Disabled")
                            .font(Font.Klymb.headline)
                            .foregroundStyle(Color.KlymbText.primary)

                        Text(isAuthorized ? "You will receive real-time rank updates" : "Enable notifications to protect your streak")
                            .font(Font.Klymb.caption)
                            .foregroundStyle(Color.KlymbText.secondary)
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
        }
    }
}

private struct PreferenceToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: KlymbSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.Klymb.bodySmall.weight(.semibold))
                    .foregroundStyle(Color.KlymbText.primary)

                Text(subtitle)
                    .font(Font.Klymb.captionSmall)
                    .foregroundStyle(Color.KlymbText.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.KlymbAccent.primary)
        }
        .padding(.horizontal, KlymbSpacing.lg)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(isOn ? "enabled" : "disabled")")
    }
}

#Preview {
    NotificationPreferencesView()
        .preferredColorScheme(.dark)
}
