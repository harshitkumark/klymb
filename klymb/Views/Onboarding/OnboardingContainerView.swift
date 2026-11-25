//
//  OnboardingContainerView.swift
//  klymb
//
//  Multi-step container hosting the onboarding flow with segmented progress bar,
//  back navigation, and Reduce Motion-safe transitions.
//

import SwiftUI

public struct OnboardingContainerView: View {
    @StateObject private var viewModel: OnboardingViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(container: AppContainerProtocol = AppContainer.mock) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(container: container))
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color.KlymbBackground.primary.ignoresSafeArea()

            VStack(spacing: 0) {
                OnboardingProgressBar(
                    currentStep: viewModel.currentStep,
                    totalSteps: OnboardingStep.allCases.count,
                    onBack: {
                        withAnimation(reduceMotion ? nil : MotionTokens.springStandard) {
                            viewModel.previousStep()
                        }
                    }
                )
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                .padding(.top, LayoutTokens.spacingS)
                .padding(.bottom, LayoutTokens.spacingM)

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
        .animation(reduceMotion ? nil : MotionTokens.springStandard, value: viewModel.currentStep)
    }
}

private struct OnboardingProgressBar: View {
    let currentStep: OnboardingStep
    let totalSteps: Int
    let onBack: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: KlymbSpacing.sm) {
            HStack {
                if currentStep != .username {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Back")
                                .font(Font.Klymb.bodySmall.weight(.medium))
                        }
                        .foregroundStyle(Color.KlymbText.secondary)
                        .frame(minHeight: 32)
                    }
                    .accessibilityLabel("Go back to previous step")
                } else {
                    Spacer().frame(width: 56)
                }

                Spacer()

                Text(currentStep.title.uppercased())
                    .font(Font.Klymb.telemetry)
                    .tracking(1.6)
                    .foregroundStyle(Color.KlymbAccent.soft)

                Spacer()

                Text("\(currentStep.stepNumber) / \(totalSteps)")
                    .font(Font.Klymb.telemetry)
                    .monospacedDigit()
                    .foregroundStyle(Color.KlymbText.tertiary)
                    .frame(width: 56, alignment: .trailing)
            }

            HStack(spacing: 5) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(
                            index <= currentStep.rawValue
                                ? Color.KlymbAccent.primary
                                : Color.KlymbBackground.tertiary
                        )
                        .frame(height: 3)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: currentStep)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(currentStep.stepNumber) of \(totalSteps): \(currentStep.title)")
        }
    }
}
