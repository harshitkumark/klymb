//
//  UsernameStepView.swift
//  klymb
//
//  Step 1: Username & Display Name selection.
//  (AGENTS.md Rule 15: SwiftUI + MVVM, Rule 18: Accessibility).
//

import SwiftUI

public struct UsernameStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @FocusState private var isUsernameFocused: Bool
    @FocusState private var isDisplayNameFocused: Bool

    public init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LayoutTokens.spacingL) {
                // Header
                VStack(alignment: .leading, spacing: LayoutTokens.spacingS) {
                    Text("CLAIM YOUR TAG")
                        .font(TypographyTokens.title1)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("Your unique handle in city and global leaderboards. Choose wisely — athletes will see this when you pass them.")
                        .font(TypographyTokens.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .accessibilityElement(children: .combine)

                // Username Card
                KlymbCard(padding: LayoutTokens.paddingM) {
                    VStack(alignment: .leading, spacing: LayoutTokens.spacingM) {
                        Text("USERNAME")
                            .font(TypographyTokens.caption1)
                            .foregroundStyle(ColorTokens.textTertiary)

                        HStack(spacing: LayoutTokens.spacingS) {
                            Text("@")
                                .font(TypographyTokens.headline)
                                .foregroundStyle(ColorTokens.electricCyan)

                            TextField("username", text: $viewModel.username)
                                .font(TypographyTokens.headline)
                                .foregroundStyle(ColorTokens.textPrimary)
                                .autocorrectionDisabled(true)
                                .textInputAutocapitalization(.never)
                                .focused($isUsernameFocused)
                                .accessibilityLabel("Username handle")
                                .accessibilityHint("Enter 3 to 20 lowercase letters, numbers, and underscores")

                            if !viewModel.username.isEmpty {
                                Image(systemName: viewModel.isUsernameValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(viewModel.isUsernameValid ? ColorTokens.neonGreen : ColorTokens.neonOrange)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(LayoutTokens.paddingM)
                        .background(ColorTokens.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusS))
                        .overlay(
                            RoundedRectangle(cornerRadius: LayoutTokens.radiusS)
                                .stroke(strokeColor, lineWidth: 1.5)
                        )

                        // Validation message
                        if let msg = viewModel.usernameValidationMessage {
                            Text(msg)
                                .font(TypographyTokens.caption1)
                                .foregroundStyle(viewModel.isUsernameValid ? ColorTokens.neonGreen : ColorTokens.neonOrange)
                                .accessibilityLabel("Validation status: \(msg)")
                        } else {
                            Text("3–20 characters, lowercase letters, numbers, underscores")
                                .font(TypographyTokens.caption2)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                }

                // Display Name Card (Optional)
                KlymbCard(padding: LayoutTokens.paddingM) {
                    VStack(alignment: .leading, spacing: LayoutTokens.spacingM) {
                        HStack {
                            Text("DISPLAY NAME")
                                .font(TypographyTokens.caption1)
                                .foregroundStyle(ColorTokens.textTertiary)
                            Spacer()
                            Text("Optional")
                                .font(TypographyTokens.caption2)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }

                        TextField("e.g. Alex Mercer", text: $viewModel.displayName)
                            .font(TypographyTokens.body)
                            .foregroundStyle(ColorTokens.textPrimary)
                            .focused($isDisplayNameFocused)
                            .padding(LayoutTokens.paddingM)
                            .background(ColorTokens.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusS))
                            .accessibilityLabel("Display name")
                    }
                }

                Spacer(minLength: 40)

                // CTA
                PrimaryButton(
                    title: "Next: Choose Avatar",
                    icon: "arrow.right",
                    isEnabled: viewModel.canProceed
                ) {
                    isUsernameFocused = false
                    isDisplayNameFocused = false
                    viewModel.nextStep()
                }
            }
            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
            .padding(.top, LayoutTokens.spacingL)
            .padding(.bottom, LayoutTokens.spacingXXL)
        }
        .scrollDismissesKeyboard(.immediately)
        .onAppear {
            if viewModel.username.isEmpty {
                isUsernameFocused = true
            }
        }
    }

    private var strokeColor: Color {
        if isUsernameFocused {
            return viewModel.isUsernameValid ? ColorTokens.neonGreen : ColorTokens.electricCyan
        }
        if !viewModel.username.isEmpty {
            return viewModel.isUsernameValid ? ColorTokens.neonGreen : ColorTokens.neonOrange
        }
        return ColorTokens.borderSubtle
    }
}
