//
//  OnboardingContainerView.swift
//  klymb
//
//  Multi-step container hosting the onboarding flow with progress indicator,
//  back navigation, and step transitions.
//  (AGENTS.md Rule 15: SwiftUI + MVVM, Rule 18: Accessibility).
//

import SwiftUI

public struct OnboardingContainerView: View {
    @StateObject private var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(container: AppContainerProtocol = AppContainer.mock) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(container: container))
    }

    public var body: some View {
        ZStack {
            ColorTokens.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Progress Bar
                OnboardingProgressBar(
                    currentStep: viewModel.currentStep,
                    totalSteps: OnboardingStep.allCases.count,
                    onBack: {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.previousStep()
                        }
                    }
                )
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                .padding(.top, LayoutTokens.spacingS)
                .padding(.bottom, LayoutTokens.spacingM)

                // Current Step Content
                Group {
                    switch viewModel.currentStep {
                    case .username:
                        UsernameStepView(viewModel: viewModel)
                    case .avatar:
                        AvatarStepView(viewModel: viewModel)
                    case .city:
                        CityStepView(viewModel: viewModel)
                    case .habits:
                        HabitStepView(viewModel: viewModel)
                    case .permissions:
                        PermissionsStepView(viewModel: viewModel)
                    case .summary:
                        OnboardingSummaryView(viewModel: viewModel)
                    }
                }
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: viewModel.currentStep)
    }
}

private struct OnboardingProgressBar: View {
    let currentStep: OnboardingStep
    let totalSteps: Int
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: LayoutTokens.spacingS) {
            HStack {
                if currentStep != .username {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                            Text("Back")
                                .font(TypographyTokens.caption1)
                        }
                        .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .accessibilityLabel("Go back to previous step")
                } else {
                    Spacer().frame(width: 48)
                }

                Spacer()

                Text(currentStep.title.uppercased())
                    .font(TypographyTokens.caption1)
                    .fontWeight(.bold)
                    .foregroundStyle(ColorTokens.electricCyan)
                    .tracking(1.5)

                Spacer()

                Text("\(currentStep.stepNumber)/\(totalSteps)")
                    .font(TypographyTokens.caption1)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(width: 48, alignment: .trailing)
            }

            // Segmented Progress Bar
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep.rawValue ? ColorTokens.electricCyan : ColorTokens.backgroundSecondary)
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.25), value: currentStep)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(currentStep.stepNumber) of \(totalSteps): \(currentStep.title)")
        }
    }
}
