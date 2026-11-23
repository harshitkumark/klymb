//
//  AvatarStepView.swift
//  klymb
//
//  Step 2: Preset Avatar Emblem selection.
//  (AGENTS.md Rule 15: SwiftUI + MVVM, Rule 18: Accessibility).
//

import SwiftUI

public struct AvatarStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private let columns = [
        GridItem(.flexible(), spacing: LayoutTokens.spacingM),
        GridItem(.flexible(), spacing: LayoutTokens.spacingM)
    ]

    public init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LayoutTokens.spacingL) {
                // Header
                VStack(alignment: .leading, spacing: LayoutTokens.spacingS) {
                    Text("SELECT EMBLEM")
                        .font(TypographyTokens.title1)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("Choose the emblem that accompanies your rank badge in the arena.")
                        .font(TypographyTokens.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .accessibilityElement(children: .combine)

                // Avatar Grid
                LazyVGrid(columns: columns, spacing: LayoutTokens.spacingM) {
                    ForEach(viewModel.avatarPresets) { preset in
                        AvatarOptionCard(
                            preset: preset,
                            isSelected: viewModel.selectedAvatar == preset.id
                        ) {
                            HapticManager.shared.selection()
                            viewModel.selectedAvatar = preset.id
                        }
                    }
                }

                Spacer(minLength: 40)

                // CTA
                PrimaryButton(
                    title: "Next: Select Arena",
                    icon: "arrow.right",
                    isEnabled: viewModel.canProceed
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

private struct AvatarOptionCard: View {
    let preset: AvatarPresetOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            KlymbCard(
                glowColor: isSelected ? ColorTokens.electricCyan.opacity(0.3) : nil,
                padding: LayoutTokens.paddingM
            ) {
                VStack(spacing: LayoutTokens.spacingM) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? ColorTokens.electricCyan.opacity(0.2) : ColorTokens.backgroundSecondary)
                            .frame(width: 56, height: 56)

                        Image(systemName: preset.iconName)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(isSelected ? ColorTokens.electricCyan : ColorTokens.textPrimary)
                    }

                    VStack(spacing: 2) {
                        Text(preset.title)
                            .font(TypographyTokens.headline)
                            .foregroundStyle(ColorTokens.textPrimary)

                        Text(preset.description)
                            .font(TypographyTokens.caption2)
                            .foregroundStyle(ColorTokens.textTertiary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }

                    if isSelected {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("SELECTED")
                                .font(.system(size: 10, weight: .heavy))
                        }
                        .foregroundStyle(ColorTokens.electricCyan)
                    } else {
                        Spacer()
                            .frame(height: 14)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 140)
            }
            .overlay(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                    .stroke(isSelected ? ColorTokens.electricCyan : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preset.title) emblem, \(preset.description)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}
