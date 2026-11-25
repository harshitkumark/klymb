//
//  UsernameStepView.swift
//  klymb
//
//  Step 1: Minimalist Username & Display Name selection.
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
            VStack(alignment: .leading, spacing: LayoutTokens.spacingXL) {
                VStack(alignment: .leading, spacing: LayoutTokens.spacingS) {
                    Text("Claim your tag")
                        .font(Font.Klymb.titleLarge)
                        .foregroundStyle(Color.KlymbText.primary)

                    Text("Your unique handle on city and global leaderboards. Athletes see this when you climb past them.")
                        .font(Font.Klymb.bodySmall)
                        .foregroundStyle(Color.KlymbText.secondary)
                }
                .accessibilityElement(children: .combine)

                VStack(alignment: .leading, spacing: KlymbSpacing.lg) {
                    // Username Input
                    VStack(alignment: .leading, spacing: KlymbSpacing.sm) {
                        KlymbSectionHeader("Username")

                        HStack(spacing: LayoutTokens.spacingS) {
                            Text("@")
                                .font(Font.Klymb.headline)
                                .foregroundStyle(Color.KlymbAccent.soft)

                            TextField("username", text: $viewModel.username)
                                .font(Font.Klymb.headline)
                                .foregroundStyle(Color.KlymbText.primary)
                                .autocorrectionDisabled(true)
                                .textInputAutocapitalization(.never)
                                .focused($isUsernameFocused)
                                .accessibilityLabel("Username handle")
                                .accessibilityHint("Enter 3 to 20 lowercase letters, numbers, and underscores")

                            if !viewModel.username.isEmpty {
                                Image(systemName: viewModel.isUsernameValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(viewModel.isUsernameValid ? Color.KlymbSemantic.success : Color.KlymbSemantic.warning)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.horizontal, KlymbSpacing.md)
                        .frame(minHeight: 50)
                        .background(Color.KlymbBackground.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous)
                                .strokeBorder(strokeColor, lineWidth: 1)
                        )

                        if let msg = viewModel.usernameValidationMessage {
                            Text(msg)
                                .font(Font.Klymb.caption)
                                .foregroundStyle(viewModel.isUsernameValid ? Color.KlymbSemantic.success : Color.KlymbSemantic.warning)
                                .accessibilityLabel("Validation status: \(msg)")
                        } else {
                            Text("3–20 characters: lowercase letters, numbers, underscores")
                                .font(Font.Klymb.captionSmall)
                                .foregroundStyle(Color.KlymbText.tertiary)
                        }
                    }

                    // Display Name Input
                    VStack(alignment: .leading, spacing: KlymbSpacing.sm) {
                        KlymbSectionHeader("Display Name", trailingText: "OPTIONAL", trailingColor: Color.KlymbText.tertiary)

                        TextField("e.g. Alex Mercer", text: $viewModel.displayName)
                            .font(Font.Klymb.body)
                            .foregroundStyle(Color.KlymbText.primary)
                            .focused($isDisplayNameFocused)
                            .padding(.horizontal, KlymbSpacing.md)
                            .frame(minHeight: 50)
                            .background(Color.KlymbBackground.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous)
                                    .strokeBorder(
                                        isDisplayNameFocused ? Color.KlymbAccent.primary.opacity(0.65) : Color.KlymbBorder.default,
                                        lineWidth: 1
                                    )
                            )
                            .accessibilityLabel("Display name")
                    }
                }

                Spacer(minLength: 32)

                PrimaryButton(
                    title: "Next: Choose Emblem",
                    icon: "arrow.right",
                    isEnabled: viewModel.canProceed
                ) {
                    isUsernameFocused = false
                    isDisplayNameFocused = false
                    viewModel.nextStep()
                }
            }
            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
            .padding(.top, LayoutTokens.spacingM)
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
        if !viewModel.username.isEmpty {
            return viewModel.isUsernameValid
                ? Color.KlymbSemantic.success.opacity(0.65)
                : Color.KlymbSemantic.warning.opacity(0.7)
        }
        return isUsernameFocused ? Color.KlymbAccent.primary.opacity(0.65) : Color.KlymbBorder.default
    }
}
