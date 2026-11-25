//
//  WelcomeView.swift
//  klymb
//
//  Welcome & Sign-in screen with matte obsidian canvas, subtle topographic elevation lines,
//  custom sliding mode control, Email + Password auth, and Sign in with Apple.
//

import SwiftUI
import AuthenticationServices

public struct WelcomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: AuthViewModel

    @State private var authMode: AuthMode = .signUp
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @FocusState private var focusedField: Field?

    private enum AuthMode: String, CaseIterable, Identifiable, Hashable {
        case signUp = "Create Account"
        case signIn = "Sign In"

        var id: String { rawValue }
    }

    private enum Field {
        case email
        case password
    }

    public init(container: AppContainerProtocol = AppContainer.mock) {
        self._viewModel = StateObject(wrappedValue: AuthViewModel(container: container))
    }

    public init(viewModel: AuthViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    private var isSignUpMode: Bool {
        authMode == .signUp
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmitEmail: Bool {
        trimmedEmail.contains("@") && trimmedEmail.contains(".") && password.count >= 6
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color.KlymbBackground.primary
                .ignoresSafeArea()

            KlymbTopographicBackdrop(accentOpacity: 0.08)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: KlymbSpacing.xl) {
                    // Editorial Brand Header
                    VStack(alignment: .leading, spacing: KlymbSpacing.lg) {
                        HStack {
                            HStack(spacing: KlymbSpacing.sm) {
                                KlymbBrandMark(size: 24)
                                Text("KLYMB")
                                    .font(Font.Klymb.telemetry)
                                    .tracking(3.5)
                                    .foregroundStyle(Color.KlymbText.primary)
                            }

                            Spacer()

                            Text("SEASON 01")
                                .font(Font.Klymb.telemetry)
                                .foregroundStyle(Color.KlymbText.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.KlymbBackground.secondary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.KlymbBorder.default, lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: KlymbSpacing.xs) {
                            Text("Outclimb\nyour city.")
                                .font(Font.Klymb.titleLarge)
                                .foregroundStyle(Color.KlymbText.primary)
                                .lineSpacing(-2)

                            Text("Your city is watching. Compete daily, earn KP, climb the ranks.")
                                .font(Font.Klymb.bodySmall)
                                .foregroundStyle(Color.KlymbText.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, KlymbSpacing.lg)

                    // Mode Switcher (Custom sliding capsule)
                    KlymbSegmentedControl(
                        options: AuthMode.allCases,
                        selection: $authMode,
                        title: { $0.rawValue }
                    )

                    // Email & Password Form
                    VStack(spacing: KlymbSpacing.md) {
                        // Email Field
                        HStack(spacing: KlymbSpacing.sm) {
                            Image(systemName: "envelope")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(focusedField == .email ? Color.KlymbAccent.soft : Color.KlymbText.secondary)
                                .frame(width: 20)
                                .accessibilityHidden(true)

                            TextField("Email address", text: $email)
                                .font(Font.Klymb.body)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocorrectionDisabled()
                                .foregroundStyle(Color.KlymbText.primary)
                                .focused($focusedField, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                                .accessibilityLabel("Email address")
                        }
                        .padding(.horizontal, KlymbSpacing.md)
                        .frame(minHeight: 50)
                        .background(Color.KlymbBackground.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous)
                                .strokeBorder(
                                    focusedField == .email ? Color.KlymbAccent.primary.opacity(0.65) : Color.KlymbBorder.default,
                                    lineWidth: 1
                                )
                        )

                        // Password Field
                        HStack(spacing: KlymbSpacing.sm) {
                            Image(systemName: "lock")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(focusedField == .password ? Color.KlymbAccent.soft : Color.KlymbText.secondary)
                                .frame(width: 20)
                                .accessibilityHidden(true)

                            Group {
                                if showPassword {
                                    TextField("Password (min 6 characters)", text: $password)
                                } else {
                                    SecureField("Password (min 6 characters)", text: $password)
                                }
                            }
                            .font(Font.Klymb.body)
                            .textInputAutocapitalization(.never)
                            .textContentType(isSignUpMode ? .newPassword : .password)
                            .autocorrectionDisabled()
                            .foregroundStyle(Color.KlymbText.primary)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit(submitEmail)
                            .accessibilityLabel("Password")

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.KlymbText.secondary)
                                    .frame(width: 32, height: 32)
                            }
                            .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                        }
                        .padding(.horizontal, KlymbSpacing.md)
                        .frame(minHeight: 50)
                        .background(Color.KlymbBackground.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous)
                                .strokeBorder(
                                    focusedField == .password ? Color.KlymbAccent.primary.opacity(0.65) : Color.KlymbBorder.default,
                                    lineWidth: 1
                                )
                        )

                        if isSignUpMode && !password.isEmpty && password.count < 6 {
                            Text("Use at least 6 characters for your password.")
                                .font(Font.Klymb.captionSmall)
                                .foregroundStyle(Color.KlymbSemantic.warning)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        PrimaryButton(
                            isSignUpMode ? "Create Account" : "Sign In",
                            icon: isSignUpMode ? "arrow.right" : "arrow.right",
                            tone: .bone,
                            isLoading: viewModel.isLoading,
                            isEnabled: canSubmitEmail
                        ) {
                            submitEmail()
                        }
                        .padding(.top, KlymbSpacing.xs)
                    }

                    // Divider
                    HStack(spacing: KlymbSpacing.md) {
                        Rectangle()
                            .fill(Color.KlymbBorder.subtle)
                            .frame(height: 1)
                        Text("or")
                            .font(Font.Klymb.caption)
                            .foregroundStyle(Color.KlymbText.tertiary)
                        Rectangle()
                            .fill(Color.KlymbBorder.subtle)
                            .frame(height: 1)
                    }

                    // Sign in with Apple
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: viewModel.configureAppleRequest,
                        onCompletion: { result in
                            viewModel.handleAppleCompletion(result, appState: appState)
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous)
                            .strokeBorder(KlymbGradient.specularBorder, lineWidth: 1)
                    )
                    .disabled(viewModel.isLoading)

                    Text("By continuing, you agree to our Terms of Service and Privacy Policy.")
                        .font(Font.Klymb.captionSmall)
                        .foregroundStyle(Color.KlymbText.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, KlymbSpacing.lg)
                }
                .padding(.horizontal, KlymbSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .alert(
            (viewModel.errorMessage?.contains("Account created!") == true) ? "Check Your Email" : "Sign In Failed",
            isPresented: $viewModel.showError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unexpected error occurred.")
        }
    }

    private func submitEmail() {
        guard canSubmitEmail, !viewModel.isLoading else { return }
        focusedField = nil
        viewModel.submitEmailAuth(
            email: email,
            password: password,
            isSignUp: isSignUpMode,
            appState: appState
        )
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
