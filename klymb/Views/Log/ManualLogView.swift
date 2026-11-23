//
//  ManualLogView.swift
//  klymb
//
//  Manual activity quick-log screen for Water, Workout, and Mindfulness (PRD §F6).
//  (AGENTS.md Rule 2 & 3: Labeled estimates, Rule 15: SwiftUI + MVVM, Rule 18: Accessibility).
//

import SwiftUI

public struct ManualLogView: View {
    @StateObject private var viewModel: ManualLogViewModel

    public init(container: AppContainerProtocol = AppContainer.mock) {
        _viewModel = StateObject(wrappedValue: ManualLogViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: LayoutTokens.spacingL) {
                        // Header
                        VStack(alignment: .leading, spacing: LayoutTokens.spacingS) {
                            Text("LOG ACTIVITY")
                                .font(TypographyTokens.title1)
                                .foregroundStyle(ColorTokens.textPrimary)

                            Text("Quickly log manual disciplines. Manual entries earn at a balanced rate to protect leaderboard fairness.")
                                .font(TypographyTokens.subheadline)
                                .foregroundStyle(ColorTokens.textSecondary)

                            HStack(spacing: 4) {
                                Image(systemName: "info.circle.fill")
                                    .font(.system(size: 11))
                                Text("Unverified • Subject to manual daily caps")
                                    .font(TypographyTokens.caption2.weight(.semibold))
                            }
                            .foregroundStyle(ColorTokens.neonOrange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ColorTokens.neonOrange.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        .padding(.top, LayoutTokens.spacingS)

                        // 1. Discipline Selector (3 options)
                        HStack(spacing: LayoutTokens.spacingS) {
                            ForEach(ManualLogType.allCases) { type in
                                DisciplineTabButton(
                                    type: type,
                                    isSelected: viewModel.selectedType == type
                                ) {
                                    viewModel.selectType(type)
                                }
                            }
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        // 2. Workout Sub-type Picker (if workout selected)
                        if viewModel.selectedType == .workout {
                            VStack(alignment: .leading, spacing: LayoutTokens.spacingS) {
                                Text("WORKOUT CATEGORY")
                                    .font(TypographyTokens.caption1)
                                    .fontWeight(.bold)
                                    .foregroundStyle(ColorTokens.textTertiary)
                                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: LayoutTokens.spacingS) {
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

                        // 3. Central Stepper & Quantity Display Card
                        KlymbCard(padding: LayoutTokens.paddingL) {
                            VStack(spacing: LayoutTokens.spacingM) {
                                Text("AMOUNT TO LOG")
                                    .font(TypographyTokens.caption2)
                                    .fontWeight(.heavy)
                                    .tracking(1.5)
                                    .foregroundStyle(ColorTokens.textTertiary)

                                HStack(spacing: LayoutTokens.spacingXL) {
                                    // Decrement Button
                                    Button {
                                        viewModel.decrement()
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(ColorTokens.backgroundSecondary)
                                                .frame(width: 48, height: 48)

                                            Image(systemName: "minus")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundStyle(ColorTokens.textPrimary)
                                        }
                                    }
                                    .accessibilityLabel("Decrease amount")

                                    // Big Number Display
                                    VStack(spacing: 0) {
                                        Text("\(Int(viewModel.quantity))")
                                            .font(.system(size: 44, weight: .black, design: .rounded))
                                            .foregroundStyle(ColorTokens.textPrimary)

                                        Text(viewModel.selectedType.unit.uppercased())
                                            .font(TypographyTokens.caption1.weight(.bold))
                                            .foregroundStyle(ColorTokens.electricCyan)
                                    }
                                    .frame(minWidth: 100)

                                    // Increment Button
                                    Button {
                                        viewModel.increment()
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(ColorTokens.backgroundSecondary)
                                                .frame(width: 48, height: 48)

                                            Image(systemName: "plus")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundStyle(ColorTokens.textPrimary)
                                        }
                                    }
                                    .accessibilityLabel("Increase amount")
                                }

                                // Quick Presets
                                HStack(spacing: LayoutTokens.spacingS) {
                                    ForEach(viewModel.selectedType.quickPresets, id: \.self) { preset in
                                        Button {
                                            viewModel.selectPreset(preset)
                                        } label: {
                                            Text("\(Int(preset)) \(viewModel.selectedType.unit)")
                                                .font(TypographyTokens.caption1.weight(.semibold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(viewModel.quantity == preset ? ColorTokens.electricCyan.opacity(0.2) : ColorTokens.backgroundSecondary)
                                                .foregroundStyle(viewModel.quantity == preset ? ColorTokens.electricCyan : ColorTokens.textSecondary)
                                                .clipShape(Capsule())
                                                .overlay(
                                                    Capsule().stroke(viewModel.quantity == preset ? ColorTokens.electricCyan : Color.clear, lineWidth: 1)
                                                )
                                        }
                                    }
                                }
                                .padding(.top, LayoutTokens.spacingS)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        // 4. Estimated KP Preview Card (Rule 2 & 3 Compliance)
                        KlymbCard(padding: LayoutTokens.paddingM) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text("ESTIMATED KP")
                                            .font(TypographyTokens.caption2.weight(.heavy))
                                            .tracking(1)
                                            .foregroundStyle(ColorTokens.textTertiary)

                                        Text("(Preview)")
                                            .font(TypographyTokens.caption2)
                                            .foregroundStyle(ColorTokens.textTertiary)
                                    }

                                    Text("Official KP awarded by server upon sync")
                                        .font(TypographyTokens.caption2)
                                        .foregroundStyle(ColorTokens.textSecondary)
                                }

                                Spacer()

                                Text("~\(viewModel.estimatedKP) KP")
                                    .font(TypographyTokens.title2.weight(.bold))
                                    .foregroundStyle(ColorTokens.electricCyan)
                            }
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                        // 5. Submit CTA Button
                        PrimaryButton(
                            "Log \(viewModel.selectedType.title)",
                            icon: "plus.circle.fill",
                            isLoading: viewModel.isSubmitting
                        ) {
                            Task {
                                await viewModel.submitActivity()
                            }
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        .padding(.top, LayoutTokens.spacingS)

                        // Error Banner
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(TypographyTokens.caption1)
                                .foregroundStyle(ColorTokens.neonRed)
                                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.bottom, LayoutTokens.spacingXXL)
                }

                // 6. Success Toast
                if viewModel.showSuccessToast {
                    HStack(spacing: LayoutTokens.spacingS) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ColorTokens.neonGreen)
                        Text(viewModel.successMessage)
                            .font(TypographyTokens.caption1.weight(.semibold))
                            .foregroundStyle(ColorTokens.textPrimary)
                    }
                    .padding(.horizontal, LayoutTokens.paddingL)
                    .padding(.vertical, LayoutTokens.paddingM)
                    .background(ColorTokens.backgroundSecondary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(ColorTokens.neonGreen.opacity(0.4), lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 10, y: 4)
                    .padding(.bottom, LayoutTokens.spacingXL)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation {
                                viewModel.showSuccessToast = false
                            }
                        }
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.showSuccessToast)
            .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("LOG")
                        .font(TypographyTokens.headline)
                        .fontWeight(.black)
                        .tracking(3)
                        .foregroundStyle(ColorTokens.textPrimary)
                }
            }
        }
    }
}

// MARK: - Discipline Tab Button
private struct DisciplineTabButton: View {
    let type: ManualLogType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            KlymbCard(
                glowColor: isSelected ? ColorTokens.electricCyan.opacity(0.2) : nil,
                padding: LayoutTokens.paddingM
            ) {
                VStack(spacing: LayoutTokens.spacingS) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? ColorTokens.electricCyan.opacity(0.2) : ColorTokens.backgroundSecondary)
                            .frame(width: 40, height: 40)

                        Image(systemName: type.iconName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? ColorTokens.electricCyan : ColorTokens.textPrimary)
                    }

                    Text(type.title)
                        .font(TypographyTokens.caption1.weight(.bold))
                        .foregroundStyle(isSelected ? ColorTokens.electricCyan : ColorTokens.textPrimary)

                    Text("Max \(type.manualDailyKPCap) KP")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
            .overlay(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                    .stroke(isSelected ? ColorTokens.electricCyan : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type.title), maximum \(type.manualDailyKPCap) KP per day")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}

// MARK: - Workout Option Chip
private struct WorkoutOptionChip: View {
    let option: WorkoutTypeOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: option.iconName)
                    .font(.system(size: 14))
                Text(option.name)
                    .font(TypographyTokens.caption1.weight(.semibold))
            }
            .padding(.horizontal, LayoutTokens.paddingM)
            .padding(.vertical, LayoutTokens.paddingS)
            .background(isSelected ? ColorTokens.electricCyan.opacity(0.2) : ColorTokens.backgroundSecondary)
            .foregroundStyle(isSelected ? ColorTokens.electricCyan : ColorTokens.textPrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? ColorTokens.electricCyan : ColorTokens.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
