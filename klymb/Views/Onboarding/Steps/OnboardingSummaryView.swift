//
//  OnboardingSummaryView.swift
//  klymb
//
//  Step 6: Final Review & Confirmation before entering the Arena.
//  (AGENTS.md Rule 15: SwiftUI + MVVM, Rule 18: Accessibility).
//

import SwiftUI

public struct OnboardingSummaryView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var appState: AppState

    public init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: LayoutTokens.spacingL) {
                // Celebration Badge
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [ColorTokens.electricCyan.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: avatarIcon)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(ColorTokens.electricCyan)
                }
                .padding(.top, LayoutTokens.spacingM)

                // Identity Headers
                VStack(spacing: LayoutTokens.spacingXS) {
                    Text(viewModel.displayName.isEmpty ? "@\(viewModel.username)" : viewModel.displayName)
                        .font(TypographyTokens.largeTitle)
                        .foregroundStyle(ColorTokens.textPrimary)

                    if !viewModel.displayName.isEmpty {
                        Text("@\(viewModel.username)")
                            .font(TypographyTokens.headline)
                            .foregroundStyle(ColorTokens.electricCyan)
                    }
                }
                .accessibilityElement(children: .combine)

                // Profile Configuration Card
                KlymbCard(padding: LayoutTokens.paddingL) {
                    VStack(spacing: LayoutTokens.spacingM) {
                        // Arena
                        SummaryRow(
                            icon: "building.2.fill",
                            label: "City Arena",
                            value: viewModel.selectedCity?.name ?? "Global",
                            accent: ColorTokens.textPrimary
                        )

                        Divider().background(ColorTokens.borderSubtle)

                        // Habits
                        SummaryRow(
                            icon: "bolt.heart.fill",
                            label: "Tracked Habits",
                            value: "\(viewModel.selectedHabitIds.count) Disciplines",
                            accent: ColorTokens.neonGreen
                        )

                        Divider().background(ColorTokens.borderSubtle)

                        // Rank
                        SummaryRow(
                            icon: "trophy.fill",
                            label: "Starting Tier",
                            value: "Rookie (0 KP)",
                            accent: ColorTokens.neonYellow
                        )
                    }
                }

                // Error Message if any
                if viewModel.showError, let error = viewModel.errorMessage {
                    Text(error)
                        .font(TypographyTokens.caption1)
                        .foregroundStyle(ColorTokens.neonOrange)
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 30)

                // Primary Launch Button
                PrimaryButton(
                    title: "Enter the Arena",
                    icon: "flag.checkered",
                    isLoading: viewModel.isSubmitting
                ) {
                    Task {
                        await viewModel.completeOnboarding(appState: appState)
                    }
                }
            }
            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
            .padding(.top, LayoutTokens.spacingM)
            .padding(.bottom, LayoutTokens.spacingXXL)
        }
    }

    private var avatarIcon: String {
        viewModel.avatarPresets.first(where: { $0.id == viewModel.selectedAvatar })?.iconName ?? "figure.run"
    }
}

private struct SummaryRow: View {
    let icon: String
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(accent)
                .frame(width: 24)

            Text(label)
                .font(TypographyTokens.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)

            Spacer()

            Text(value)
                .font(TypographyTokens.headline)
                .foregroundStyle(accent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
