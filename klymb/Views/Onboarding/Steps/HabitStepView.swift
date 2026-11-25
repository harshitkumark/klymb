//
//  HabitStepView.swift
//  klymb
//
//  Step 4: Habit Selection inside a unified grouped container with Daily KP Caps.
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
                    VStack(alignment: .leading, spacing: LayoutTokens.spacingS) {
                        Text("Pick your habits")
                            .font(Font.Klymb.titleLarge)
                            .foregroundStyle(Color.KlymbText.primary)

                        Text("Select which disciplines earn KP each day. You can change these anytime in Settings.")
                            .font(Font.Klymb.bodySmall)
                            .foregroundStyle(Color.KlymbText.secondary)
                    }
                    .accessibilityElement(children: .combine)

                    KlymbSectionHeader(
                        "Disciplines",
                        trailingText: "\(viewModel.selectedHabitIds.count)/\(viewModel.habits.count) SELECTED (REC: 3+)",
                        trailingColor: viewModel.selectedHabitIds.count >= 3 ? Color.KlymbSemantic.success : Color.KlymbAccent.soft
                    )

                    KlymbGroupedSurface {
                        ForEach(Array(viewModel.habits.enumerated()), id: \.element.id) { index, habit in
                            if index > 0 {
                                Divider()
                                    .background(Color.KlymbBorder.subtle)
                                    .padding(.leading, 52)
                            }
                            HabitSelectionRow(
                                habit: habit,
                                isSelected: viewModel.selectedHabitIds.contains(habit.id)
                            ) {
                                viewModel.toggleHabit(id: habit.id)
                            }
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                .padding(.top, LayoutTokens.spacingM)
                .padding(.bottom, LayoutTokens.spacingXXL)
            }

            VStack(spacing: 0) {
                Divider().background(Color.KlymbBorder.subtle)

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
            .background(Color.KlymbBackground.primary)
        }
    }
}

private struct HabitSelectionRow: View {
    let habit: Habit
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KlymbSpacing.md) {
                Image(systemName: KlymbIconCatalog.habitIcon(for: habit.key))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.KlymbAccent.soft : Color.KlymbText.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: KlymbSpacing.sm) {
                        Text(habit.displayName)
                            .font(Font.Klymb.headline)
                            .foregroundStyle(Color.KlymbText.primary)

                        if habit.manualAllowed {
                            Text("Manual")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.KlymbText.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.KlymbBackground.tertiary)
                                .clipShape(Capsule())
                        }
                    }

                    Text("Unit: \(habit.unit)  •  Cap \(habit.dailyKPCap) KP/day")
                        .font(Font.Klymb.captionSmall)
                        .foregroundStyle(Color.KlymbText.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.KlymbSemantic.success : Color.KlymbText.tertiary)
            }
            .padding(.horizontal, KlymbSpacing.lg)
            .padding(.vertical, 14)
            .background(isSelected ? Color.KlymbSemantic.success.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(habit.displayName), max \(habit.dailyKPCap) KP per day")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}
