//
//  HabitStepView.swift
//  klymb
//
//  Step 4: Habit Selection with Daily KP Caps and Units.
//  (AGENTS.md Rule 15: SwiftUI + MVVM, Rule 18: Accessibility).
//

import SwiftUI

public struct HabitStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    public init(viewModel: OnboardingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: LayoutTokens.spacingL) {
                    // Header
                    VStack(alignment: .leading, spacing: LayoutTokens.spacingS) {
                        Text("SELECT YOUR DISCIPLINES")
                            .font(TypographyTokens.title1)
                            .foregroundStyle(ColorTokens.textPrimary)

                        Text("Select which habits you want to track to earn KP every day. You can change these anytime in Settings.")
                            .font(TypographyTokens.subheadline)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .accessibilityElement(children: .combine)

                    // Recommended count pill
                    HStack(spacing: LayoutTokens.spacingS) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(ColorTokens.neonYellow)

                        Text("\(viewModel.selectedHabitIds.count) of \(viewModel.habits.count) selected (Recommended: 3+ for streak XP)")
                            .font(TypographyTokens.caption1)
                            .foregroundStyle(ColorTokens.textPrimary)
                    }
                    .padding(.horizontal, LayoutTokens.paddingM)
                    .padding(.vertical, LayoutTokens.paddingS)
                    .background(ColorTokens.neonYellow.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(ColorTokens.neonYellow.opacity(0.3), lineWidth: 1)
                    )

                    // Habits List
                    VStack(spacing: LayoutTokens.spacingM) {
                        ForEach(viewModel.habits) { habit in
                            HabitSelectionCard(
                                habit: habit,
                                isSelected: viewModel.selectedHabitIds.contains(habit.id)
                            ) {
                                viewModel.toggleHabit(id: habit.id)
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                .padding(.top, LayoutTokens.spacingL)
                .padding(.bottom, LayoutTokens.spacingXXL)
            }

            // Fixed Bottom CTA
            VStack {
                Divider()
                    .background(ColorTokens.borderSubtle)

                PrimaryButton(
                    title: "Next: Permissions",
                    icon: "arrow.right",
                    isEnabled: viewModel.canProceed
                ) {
                    viewModel.nextStep()
                }
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                .padding(.vertical, LayoutTokens.spacingM)
            }
            .background(ColorTokens.backgroundPrimary)
        }
    }
}

private struct HabitSelectionCard: View {
    let habit: Habit
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            KlymbCard(
                glowColor: isSelected ? ColorTokens.neonGreen.opacity(0.2) : nil,
                padding: LayoutTokens.paddingM
            ) {
                HStack(spacing: LayoutTokens.spacingM) {
                    // Habit Icon
                    ZStack {
                        Circle()
                            .fill(isSelected ? ColorTokens.neonGreen.opacity(0.2) : ColorTokens.backgroundSecondary)
                            .frame(width: 44, height: 44)

                        Image(systemName: iconName(for: habit.key))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(isSelected ? ColorTokens.neonGreen : ColorTokens.textPrimary)
                    }

                    // Habit details
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: LayoutTokens.spacingS) {
                            Text(habit.displayName)
                                .font(TypographyTokens.headline)
                                .foregroundStyle(ColorTokens.textPrimary)

                            if habit.manualAllowed {
                                Text("Manual ok")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(ColorTokens.textTertiary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(ColorTokens.backgroundSecondary)
                                    .clipShape(Capsule())
                            }
                        }

                        HStack(spacing: LayoutTokens.spacingS) {
                            Text("Unit: \(habit.unit)")
                                .font(TypographyTokens.caption2)
                                .foregroundStyle(ColorTokens.textTertiary)

                            Text("•")
                                .font(TypographyTokens.caption2)
                                .foregroundStyle(ColorTokens.textTertiary)

                            Text("Cap: \(habit.dailyKPCap) KP/day")
                                .font(TypographyTokens.caption2)
                                .foregroundStyle(ColorTokens.electricCyan)
                        }
                    }

                    Spacer()

                    // Selection Checkbox
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(isSelected ? ColorTokens.neonGreen : ColorTokens.textTertiary)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                    .stroke(isSelected ? ColorTokens.neonGreen : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.displayName), max \(habit.dailyKPCap) KP per day")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }

    private func iconName(for key: String) -> String {
        switch key {
        case "steps": return "figure.walk"
        case "running": return "figure.run"
        case "walking_distance": return "map.fill"
        case "workout": return "dumbbell.fill"
        case "hydration": return "drop.fill"
        case "sleep": return "bed.double.fill"
        case "mindfulness": return "brain.head.profile"
        default: return "flame.fill"
        }
    }
}
