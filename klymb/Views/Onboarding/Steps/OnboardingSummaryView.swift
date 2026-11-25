//
//  OnboardingSummaryView.swift
//  klymb
//
//  Step 6: Final Review & Confirmation before entering the Arena.
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
            VStack(spacing: LayoutTokens.spacingXL) {
                // Emblem Header
                ZStack {
                    Circle()
                        .fill(Color.KlymbAccent.primaryMuted)
                        .frame(width: 96, height: 96)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.KlymbAccent.primary.opacity(0.5), lineWidth: 1.5)
                        )

                    Image(systemName: avatarIcon)
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(Color.KlymbAccent.soft)
                }
                .padding(.top, LayoutTokens.spacingM)

                // Identity
                VStack(spacing: 4) {
                    Text(viewModel.displayName.isEmpty ? "@\(viewModel.username)" : viewModel.displayName)
                        .font(Font.Klymb.titleLarge)
                        .foregroundStyle(Color.KlymbText.primary)

                    if !viewModel.displayName.isEmpty {
                        Text("@\(viewModel.username)")
                            .font(Font.Klymb.headline)
                            .foregroundStyle(Color.KlymbAccent.soft)
                    }
                }
                .accessibilityElement(children: .combine)

                // Unified Configuration Surface
                KlymbGroupedSurface {
                    SummaryRow(
                        icon: "building.2.fill",
                        label: "City Arena",
                        value: viewModel.selectedCity?.name ?? "Global",
                        accent: Color.KlymbText.primary
                    )

                    Divider()
                        .background(Color.KlymbBorder.subtle)
                        .padding(.leading, 48)

                    SummaryRow(
                        icon: "bolt.heart.fill",
                        label: "Tracked Habits",
                        value: "\(viewModel.selectedHabitIds.count) Disciplines",
                        accent: Color.KlymbSemantic.success
                    )

                    Divider()
                        .background(Color.KlymbBorder.subtle)
                        .padding(.leading, 48)

                    SummaryRow(
                        icon: "trophy.fill",
                        label: "Starting Tier",
                        value: "Rookie (0 KP)",
                        accent: Color.KlymbAccent.soft
                    )
                }

                if viewModel.showError, let error = viewModel.errorMessage {
                    Text(error)
                        .font(Font.Klymb.caption)
                        .foregroundStyle(Color.KlymbSemantic.error)
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 24)

                PrimaryButton(
                    title: "Enter the Arena",
                    icon: "flag.checkered",
                    tone: .terracotta,
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
        viewModel.avatarPresets.first(where: { $0.id == viewModel.selectedAvatar })?.iconName ?? KlymbIconCatalog.avatarIcon(for: viewModel.selectedAvatar)
    }
}

private struct SummaryRow: View {
    let icon: String
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        HStack(spacing: KlymbSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 24)

            Text(label)
                .font(Font.Klymb.bodySmall)
                .foregroundStyle(Color.KlymbText.secondary)

            Spacer()

            Text(value)
                .font(Font.Klymb.headline)
                .foregroundStyle(accent)
        }
        .padding(.horizontal, KlymbSpacing.lg)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
