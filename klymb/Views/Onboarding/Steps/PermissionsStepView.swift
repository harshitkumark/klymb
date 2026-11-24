//
//  PermissionsStepView.swift
//  klymb
//
//  Step 5: Permissions primer for Apple HealthKit and Push Notifications.
//  (AGENTS.md Rule 15: SwiftUI + MVVM, Rule 17: No health data leak, Rule 18: Accessibility).
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
                // Header
                VStack(alignment: .leading, spacing: LayoutTokens.spacingS) {
                    Text("CONNECT SENSORS")
                        .font(TypographyTokens.title1)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("Klymb is an authentic competition powered by verified device telemetry. Connect your data sources to start scoring KP.")
                        .font(TypographyTokens.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .accessibilityElement(children: .combine)

                // HealthKit Primer Card
                KlymbCard(
                    glowColor: viewModel.healthKitRequested ? ColorTokens.neonGreen.opacity(0.2) : nil,
                    padding: LayoutTokens.paddingL
                ) {
                    VStack(alignment: .leading, spacing: LayoutTokens.spacingM) {
                        HStack(spacing: LayoutTokens.spacingM) {
                            ZStack {
                                Circle()
                                    .fill(ColorTokens.neonOrange.opacity(0.15))
                                    .frame(width: 48, height: 48)

                                Image(systemName: "heart.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(ColorTokens.neonOrange)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apple Health")
                                    .font(TypographyTokens.headline)
                                    .foregroundStyle(ColorTokens.textPrimary)

                                Text("Automated Activity Sync")
                                    .font(TypographyTokens.caption1)
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }

                            Spacer()

                            if viewModel.healthKitRequested {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(ColorTokens.neonGreen)
                            }
                        }

                        Text("Syncs steps, workouts, and distance directly. Your private health metrics remain on your device and are never sold or shared with third parties.")
                            .font(TypographyTokens.subheadline)
                            .foregroundStyle(ColorTokens.textSecondary)

                        Button {
                            Task {
                                await viewModel.requestHealthKitPermission()
                            }
                        } label: {
                            HStack {
                                Text(viewModel.healthKitRequested ? "HealthKit Connected" : "Connect Apple Health")
                                    .font(TypographyTokens.caption1.weight(.bold))
                                Spacer()
                                Image(systemName: viewModel.healthKitRequested ? "checkmark" : "chevron.right")
                            }
                            .padding(.horizontal, LayoutTokens.paddingM)
                            .padding(.vertical, LayoutTokens.paddingS)
                            .background(viewModel.healthKitRequested ? ColorTokens.neonGreen.opacity(0.15) : ColorTokens.backgroundSecondary)
                            .foregroundStyle(viewModel.healthKitRequested ? ColorTokens.neonGreen : ColorTokens.electricCyan)
                            .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusS))
                        }
                    }
                }

                // Push Notifications Primer Card
                KlymbCard(
                    glowColor: viewModel.notificationsRequested ? ColorTokens.electricCyan.opacity(0.2) : nil,
                    padding: LayoutTokens.paddingL
                ) {
                    VStack(alignment: .leading, spacing: LayoutTokens.spacingM) {
                        HStack(spacing: LayoutTokens.spacingM) {
                            ZStack {
                                Circle()
                                    .fill(ColorTokens.electricCyan.opacity(0.15))
                                    .frame(width: 48, height: 48)

                                Image(systemName: "bell.badge.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(ColorTokens.electricCyan)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Competition Alerts")
                                    .font(TypographyTokens.headline)
                                    .foregroundStyle(ColorTokens.textPrimary)

                                Text("Overtake & Streak Warnings")
                                    .font(TypographyTokens.caption1)
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }

                            Spacer()

                            if viewModel.notificationsRequested {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(ColorTokens.electricCyan)
                            }
                        }

                        Text("Receive instant alerts when an athlete overtakes your city rank, or when your daily streak is in danger of expiring.")
                            .font(TypographyTokens.subheadline)
                            .foregroundStyle(ColorTokens.textSecondary)

                        Button {
                            Task {
                                await viewModel.requestNotificationPermission()
                            }
                        } label: {
                            HStack {
                                Text(viewModel.notificationsRequested ? "Alerts Enabled" : "Enable Competition Alerts")
                                    .font(TypographyTokens.caption1.weight(.bold))
                                Spacer()
                                Image(systemName: viewModel.notificationsRequested ? "checkmark" : "chevron.right")
                            }
                            .padding(.horizontal, LayoutTokens.paddingM)
                            .padding(.vertical, LayoutTokens.paddingS)
                            .background(viewModel.notificationsRequested ? ColorTokens.electricCyan.opacity(0.15) : ColorTokens.backgroundSecondary)
                            .foregroundStyle(viewModel.notificationsRequested ? ColorTokens.electricCyan : ColorTokens.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusS))
                        }
                    }
                }

                Spacer(minLength: 40)

                // CTA
                PrimaryButton(
                    title: "Next: Review Profile",
                    icon: "arrow.right"
                ) {
                    viewModel.nextStep()
                }
            }
            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
            .padding(.top, LayoutTokens.spacingL)
            .padding(.bottom, LayoutTokens.spacingXXL)
        }
    }
}
