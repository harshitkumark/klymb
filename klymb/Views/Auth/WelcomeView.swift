//
//  WelcomeView.swift
//  klymb
//
//  Welcome & Sign-in screen matching docs/DESIGN_SYSTEM.md §8.2 & §9.
//  Clean Email + Password sign up / sign in alongside Sign in with Apple.
//

import SwiftUI
import AuthenticationServices

public struct WelcomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: AuthViewModel

    @State private var isSignUpMode: Bool = true
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @FocusState private var focusedField: Field?

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

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmitEmail: Bool {
        trimmedEmail.contains("@") && trimmedEmail.contains(".") && password.count >= 6
    }

    public var body: some View {
        ZStack {
            Color.KlymbBackground.primary
                .ignoresSafeArea()

            // Subtle top radial glow
            Circle()
                .fill(Color.KlymbAccent.primary.opacity(0.12))
                .blur(radius: 80)
                .frame(width: 300, height: 300)
                .offset(y: -180)
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: KlymbSpacing.lg) {
                    // Hero Branding
                    VStack(spacing: KlymbSpacing.sm) {
                        ZStack {
                            Circle()
                                .fill(Color.KlymbBackground.secondary)
                                .frame(width: 78, height: 78)
                                .overlay(
                                    Circle()
                                        .stroke(Color.KlymbAccent.primary, lineWidth: 2)
                                )
                                .shadow(color: Color.KlymbAccent.primary.opacity(0.3), radius: 14)

                            Image(systemName: "flame.fill")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(KlymbGradient.fire)
                                .accessibilityHidden(true)
                        }

                        Text("KLYMB")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .tracking(3)
                            .foregroundStyle(Color.KlymbText.primary)

                        Text("Your city is watching.")
                            .font(Font.Klymb.headline)
                            .foregroundStyle(Color.KlymbAccent.primary)

                        Text("Compete with your city. Earn KP. Climb the ranks.")
                            .font(Font.Klymb.caption)
                            .foregroundStyle(Color.KlymbText.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, KlymbSpacing.xl)

                    // Mode Switcher (Sign Up / Sign In)
                    Picker("Authentication Mode", selection: $isSignUpMode) {
                        Text("Create Account").tag(true)
                        Text("Sign In").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Authentication mode")

                    // Email & Password Form
                    VStack(spacing: KlymbSpacing.md) {
                        HStack(spacing: KlymbSpacing.sm) {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(Color.KlymbText.secondary)
                                .frame(width: 20)
                                .accessibilityHidden(true)

                            TextField("Email address", text: $email)
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
                        .frame(height: 50)
                        .background(Color.KlymbBackground.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: KlymbRadius.md)
                                .stroke(
                                    focusedField == .email ? Color.KlymbAccent.primary : Color.KlymbBorder.default,
                                    lineWidth: 1
                                )
                        )

                        HStack(spacing: KlymbSpacing.sm) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(Color.KlymbText.secondary)
                                .frame(width: 20)
                                .accessibilityHidden(true)

                            Group {
                                if showPassword {
                                    TextField("Password (min 6 characters)", text: $password)
                                } else {
                                    SecureField("Password (min 6 characters)", text: $password)
                                }
                            }
                            .textInputAutocapitalization(.never)
                            .textContentType(isSignUpMode ? .newPassword : .password)
                            .autocorrectionDisabled()
                            .foregroundStyle(Color.KlymbText.primary)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit(submitEmail)
                            .accessibilityLabel("Password")

                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(Color.KlymbText.secondary)
                            }
                            .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                        }
                        .padding(.horizontal, KlymbSpacing.md)
                        .frame(height: 50)
                        .background(Color.KlymbBackground.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: KlymbRadius.md)
                                .stroke(
                                    focusedField == .password ? Color.KlymbAccent.primary : Color.KlymbBorder.default,
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
                            icon: isSignUpMode ? "person.badge.plus" : "arrow.right",
                            isLoading: viewModel.isLoading,
                            isEnabled: canSubmitEmail
                        ) {
                            submitEmail()
                        }
                    }

                    // Divider
                    HStack(spacing: KlymbSpacing.sm) {
                        Rectangle()
                            .fill(Color.KlymbBorder.default)
                            .frame(height: 1)
                        Text("OR")
                            .font(Font.Klymb.captionSmall)
                            .foregroundStyle(Color.KlymbText.tertiary)
                        Rectangle()
                            .fill(Color.KlymbBorder.default)
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
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.lg))
                    .shadow(color: Color.white.opacity(0.12), radius: 8)
                    .disabled(viewModel.isLoading)

                    Text("By continuing, you agree to our Terms of Service and Privacy Policy.")
                        .font(Font.Klymb.captionSmall)
                        .foregroundStyle(Color.KlymbText.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, KlymbSpacing.lg)
                }
                .padding(.horizontal, KlymbSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
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
}
