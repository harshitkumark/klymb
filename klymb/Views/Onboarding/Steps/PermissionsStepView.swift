//
//  PermissionsStepView.swift
//  klymb
//
//  Step 5: Permissions primer for Apple HealthKit and Push Notifications.
//  Preserves AGENTS.md Rule 17 privacy commitment.
//

import SwiftUI

public struct PermissionsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    public init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LayoutTokens.spacingL) {
                VStack(alignment: .leading, spacing: LayoutTokens.spacingS) {
                    Text("Connect sensors")
                        .font(Font.Klymb.titleLarge)
                        .foregroundStyle(Color.KlymbText.primary)

                    Text("Klymb is an authentic competition powered by verified device telemetry. Connect your data sources to start scoring KP.")
                        .font(Font.Klymb.bodySmall)
                        .foregroundStyle(Color.KlymbText.secondary)
                }
                .accessibilityElement(children: .combine)

                // Apple HealthCard
                KlymbCard(
                    glowColor: viewModel.healthKitRequested ? Color.KlymbSemantic.success : nil,
                    padding: KlymbSpacing.lg,
                    isElevated: true
                ) {
                    VStack(alignment: .leading, spacing: KlymbSpacing.md) {
                        HStack(spacing: KlymbSpacing.md) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.KlymbAccent.soft)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apple Health")
                                    .font(Font.Klymb.headline)
                                    .foregroundStyle(Color.KlymbText.primary)

                                Text("Automated Activity Sync")
                                    .font(Font.Klymb.caption)
                                    .foregroundStyle(Color.KlymbText.secondary)
                            }

                            Spacer()

                            if viewModel.healthKitRequested {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.KlymbSemantic.success)
                            }
                        }

                        Text("Syncs steps, workouts, and distance directly. Your private health metrics remain on your device and are never sold or shared with third parties.")
                            .font(Font.Klymb.bodySmall)
                            .foregroundStyle(Color.KlymbText.secondary)

                        Button {
                            Task {
                                await viewModel.requestHealthKitPermission()
                            }
                        } label: {
                            HStack {
                                Text(viewModel.healthKitRequested ? "HealthKit Connected" : "Connect Apple Health")
                                    .font(Font.Klymb.caption.weight(.semibold))
                                Spacer()
                                Image(systemName: viewModel.healthKitRequested ? "checkmark" : "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .padding(.horizontal, KlymbSpacing.md)
                            .padding(.vertical, 10)
                            .background(viewModel.healthKitRequested ? Color.KlymbSemantic.success.opacity(0.14) : Color.KlymbBackground.tertiary)
                            .foregroundStyle(viewModel.healthKitRequested ? Color.KlymbSemantic.success : Color.KlymbText.primary)
                            .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.sm, style: .continuous))
                        }
                        .buttonStyle(KlymbPressableButtonStyle())
                    }
                }

                // Competition Alerts Card
                KlymbCard(
                    glowColor: viewModel.notificationsRequested ? Color.KlymbAccent.primary : nil,
                    padding: KlymbSpacing.lg
                ) {
                    VStack(alignment: .leading, spacing: KlymbSpacing.md) {
                        HStack(spacing: KlymbSpacing.md) {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.KlymbAccent.soft)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Competition Alerts")
                                    .font(Font.Klymb.headline)
                                    .foregroundStyle(Color.KlymbText.primary)

                                Text("Overtake & Streak Warnings")
                                    .font(Font.Klymb.caption)
                                    .foregroundStyle(Color.KlymbText.secondary)
                            }

                            Spacer()

                            if viewModel.notificationsRequested {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.KlymbSemantic.success)
                            }
                        }

                        Text("Receive alerts when a rival passes your city rank, or when your daily streak is about to expire.")
                            .font(Font.Klymb.bodySmall)
                            .foregroundStyle(Color.KlymbText.secondary)

                        Button {
                            Task {
                                await viewModel.requestNotificationPermission()
                            }
                        } label: {
                            HStack {
                                Text(viewModel.notificationsRequested ? "Alerts Enabled" : "Enable Competition Alerts")
                                    .font(Font.Klymb.caption.weight(.semibold))
                                Spacer()
                                Image(systemName: viewModel.notificationsRequested ? "checkmark" : "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .padding(.horizontal, KlymbSpacing.md)
                            .padding(.vertical, 10)
                            .background(viewModel.notificationsRequested ? Color.KlymbAccent.primaryMuted : Color.KlymbBackground.tertiary)
                            .foregroundStyle(viewModel.notificationsRequested ? Color.KlymbAccent.soft : Color.KlymbText.primary)
                            .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.sm, style: .continuous))
                        }
                        .buttonStyle(KlymbPressableButtonStyle())
                    }
                }

                Spacer(minLength: 32)

                PrimaryButton(
                    title: "Next: Review Profile",
                    icon: "arrow.right"
                ) {
                    viewModel.nextStep()
                }
            }
            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
            .padding(.top, LayoutTokens.spacingM)
            .padding(.bottom, LayoutTokens.spacingXXL)
        }
    }
}
