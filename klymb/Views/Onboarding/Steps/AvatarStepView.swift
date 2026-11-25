//
//  AvatarStepView.swift
//  klymb
//
//  Step 2: Preset Avatar Emblem selection.
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
                VStack(alignment: .leading, spacing: LayoutTokens.spacingS) {
                    Text("Select emblem")
                        .font(Font.Klymb.titleLarge)
                        .foregroundStyle(Color.KlymbText.primary)

                    Text("Choose the crest that accompanies your rank across your city arena.")
                        .font(Font.Klymb.bodySmall)
                        .foregroundStyle(Color.KlymbText.secondary)
                }
                .accessibilityElement(children: .combine)

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

                Spacer(minLength: 32)

                PrimaryButton(
                    title: "Next: Select Arena",
                    icon: "arrow.right",
                    isEnabled: viewModel.canProceed
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

private struct AvatarOptionCard: View {
    let preset: AvatarPresetOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: KlymbSpacing.md) {
                HStack {
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.KlymbAccent.soft : Color.KlymbText.tertiary)
                }

                Image(systemName: preset.iconName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.KlymbAccent.soft : Color.KlymbText.primary)
                    .frame(height: 36)

                VStack(spacing: 3) {
                    Text(preset.title)
                        .font(Font.Klymb.headline)
                        .foregroundStyle(Color.KlymbText.primary)

                    Text(preset.description)
                        .font(Font.Klymb.captionSmall)
                        .foregroundStyle(Color.KlymbText.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(KlymbSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 138)
            .klymbCardStyle(
                cornerRadius: KlymbRadius.lg,
                isHighlighted: isSelected,
                isElevated: isSelected
            )
        }
        .buttonStyle(KlymbPressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preset.title) emblem, \(preset.description)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}
