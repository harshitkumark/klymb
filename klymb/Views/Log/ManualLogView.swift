//
//  ManualLogView.swift
//  klymb
//
//  Manual activity quick-log console for Hydration, Workout, and Mindfulness.
//  Preserves AGENTS.md Rules 2 & 3 (server-authoritative scoring, preview estimates).
//

import SwiftUI

public struct ManualLogView: View {
    @StateObject private var viewModel: ManualLogViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(container: AppContainerProtocol = AppContainer.mock) {
        _viewModel = StateObject(wrappedValue: ManualLogViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.KlymbBackground.primary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: KlymbSpacing.lg) {
                        // 1. Clean Editorial Header
                        VStack(alignment: .leading, spacing: KlymbSpacing.xs) {
                            Text("Quick Log")
                                .font(Font.Klymb.titleLarge)
                                .foregroundStyle(Color.KlymbText.primary)

                            Text("Manual entries score at 0.5x to protect city leaderboard fairness.")
                                .font(Font.Klymb.bodySmall)
                                .foregroundStyle(Color.KlymbText.secondary)
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        .padding(.top, KlymbSpacing.sm)

                        // 2. Sliding Discipline Selector
                        KlymbSegmentedControl(
                            options: ManualLogType.allCases,
                            selection: Binding(
                                get: { viewModel.selectedType },
                                set: { viewModel.selectType($0) }
                            ),
                            title: { $0.title },
                            accentSelectionText: true,
                            onSelect: { viewModel.selectType($0) }
                        )
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        // 3. Workout Category Chips
                        if viewModel.selectedType == .workout {
                            VStack(alignment: .leading, spacing: KlymbSpacing.sm) {
                                KlymbSectionHeader("Workout Type")
                                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: KlymbSpacing.sm) {
                                        ForEach(WorkoutTypeOption.allOptions) { option in
                                            WorkoutOptionChip(
                                                option: option,
                                                isSelected: viewModel.selectedWorkoutType == option
                                            ) {
                                                HapticManager.shared.selection()
                                                viewModel.selectedWorkoutType = option
                                            }
                                        }
                                    }
                                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                                }
                            }
                        }

                        // 4. Consolidated Precision Console + Inline Estimated Preview Footer
                        VStack(spacing: 0) {
                            VStack(spacing: KlymbSpacing.lg) {
                                Text("\(viewModel.selectedType.title.uppercased()) AMOUNT")
                                    .font(Font.Klymb.telemetry)
                                    .tracking(1.4)
                                    .foregroundStyle(Color.KlymbText.secondary)

                                HStack(spacing: KlymbSpacing.xl) {
                                    StepperButton(symbol: "minus", accessibilityTitle: "Decrease amount") {
                                        viewModel.decrement()
                                    }

                                    VStack(spacing: 2) {
                                        Text("\(Int(viewModel.quantity))")
                                            .font(.system(size: 52, weight: .heavy).width(.condensed))
                                            .monospacedDigit()
                                            .foregroundStyle(Color.KlymbText.primary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                            .contentTransition(reduceMotion ? .identity : .numericText(value: viewModel.quantity))

                                        Text(viewModel.selectedType.unit.uppercased())
                                            .font(Font.Klymb.telemetry)
                                            .tracking(1.5)
                                            .foregroundStyle(Color.KlymbAccent.soft)
                                    }
                                    .frame(minWidth: 112)
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("Current amount: \(Int(viewModel.quantity)) \(viewModel.selectedType.unit)")
                                    .accessibilityValue("\(Int(viewModel.quantity)) \(viewModel.selectedType.unit)")

                                    StepperButton(symbol: "plus", accessibilityTitle: "Increase amount") {
                                        viewModel.increment()
                                    }
                                }

                                // Quick Presets Row
                                HStack(spacing: KlymbSpacing.sm) {
                                    ForEach(viewModel.selectedType.quickPresets, id: \.self) { preset in
                                        let isSelected = viewModel.quantity == preset
                                        Button {
                                            viewModel.selectPreset(preset)
                                        } label: {
                                            Text("\(Int(preset))")
                                                .font(Font.Klymb.telemetry)
                                                .monospacedDigit()
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(isSelected ? Color.KlymbAccent.primaryMuted : Color.KlymbBackground.tertiary)
                                                .foregroundStyle(isSelected ? Color.KlymbAccent.soft : Color.KlymbText.secondary)
                                                .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.sm, style: .continuous))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: KlymbRadius.sm, style: .continuous)
                                                        .strokeBorder(
                                                            isSelected ? Color.KlymbAccent.primary.opacity(0.6) : Color.KlymbBorder.subtle,
                                                            lineWidth: 1
                                                        )
                                                )
                                        }
                                        .buttonStyle(KlymbPressableButtonStyle())
                                        .accessibilityLabel("\(Int(preset)) \(viewModel.selectedType.unit)")
                                    }
                                }
                            }
                            .padding(.horizontal, KlymbSpacing.lg)
                            .padding(.vertical, KlymbSpacing.xl)

                            Divider().background(Color.KlymbBorder.subtle)

                            // Integrated Estimate Footer (Rule 2 & 3 Compliance)
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Estimated Preview")
                                        .font(Font.Klymb.caption.weight(.semibold))
                                        .foregroundStyle(Color.KlymbText.primary)

                                    Text("Unverified • Daily cap \(viewModel.selectedType.manualDailyKPCap) KP • Server-verified")
                                        .font(Font.Klymb.captionSmall)
                                        .foregroundStyle(Color.KlymbText.secondary)
                                }

                                Spacer(minLength: KlymbSpacing.sm)

                                Text("~\(viewModel.estimatedKP) KP")
                                    .font(Font.Klymb.athleticMetric)
                                    .foregroundStyle(Color.KlymbAccent.soft)
                            }
                            .padding(.horizontal, KlymbSpacing.lg)
                            .padding(.vertical, 14)
                            .background(Color.KlymbBackground.primary.opacity(0.35))
                        }
                        .klymbCardStyle(cornerRadius: KlymbRadius.xl, isElevated: true)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        // 5. Submit CTA Button
                        PrimaryButton(
                            "Log \(Int(viewModel.quantity)) \(viewModel.selectedType.unit)",
                            icon: "plus",
                            tone: .bone,
                            isLoading: viewModel.isSubmitting
                        ) {
                            Task {
                                await viewModel.submitActivity()
                            }
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(Font.Klymb.caption)
                                .foregroundStyle(Color.KlymbSemantic.error)
                                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.bottom, KlymbSpacing.xl)
                }

                // 6. Floating Glass Toast
                if viewModel.showSuccessToast {
                    KlymbToastBanner(
                        icon: "checkmark.circle.fill",
                        message: viewModel.successMessage,
                        trailingLabel: "SYNCED",
                        accentColor: Color.KlymbSemantic.success
                    )
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    .padding(.bottom, KlymbSpacing.lg)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation(reduceMotion ? nil : MotionTokens.springStandard) {
                                viewModel.showSuccessToast = false
                            }
                        }
                    }
                }
            }
            .animation(reduceMotion ? nil : MotionTokens.springStandard, value: viewModel.showSuccessToast)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct StepperButton: View {
    let symbol: String
    let accessibilityTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous)
                    .fill(Color.KlymbBackground.tertiary)
                    .frame(width: 50, height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: KlymbRadius.lg, style: .continuous)
                            .strokeBorder(KlymbGradient.specularBorder, lineWidth: 1)
                    )

                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.KlymbText.primary)
            }
        }
        .buttonStyle(KlymbPressableButtonStyle())
        .accessibilityLabel(accessibilityTitle)
    }
}

private struct WorkoutOptionChip: View {
    let option: WorkoutTypeOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: option.iconName)
                    .font(.system(size: 13, weight: .medium))
                Text(option.name)
                    .font(Font.Klymb.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.KlymbAccent.primaryMuted : Color.KlymbBackground.secondary)
            .foregroundStyle(isSelected ? Color.KlymbAccent.soft : Color.KlymbText.secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.KlymbAccent.primary.opacity(0.6) : Color.KlymbBorder.default,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(KlymbPressableButtonStyle())
    }
}

#Preview {
    ManualLogView()
        .preferredColorScheme(.dark)
}
