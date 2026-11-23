//
//  CityStepView.swift
//  klymb
//
//  Step 3: City Arena selection with 30-day change limitation notice.
//  (AGENTS.md Rule 15: SwiftUI + MVVM, Rule 18: Accessibility).
//

import SwiftUI

public struct CityStepView: View {
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
                        Text("CHOOSE YOUR ARENA")
                            .font(TypographyTokens.title1)
                            .foregroundStyle(ColorTokens.textPrimary)

                        Text("You will represent and compete for this city on local and regional leaderboards.")
                            .font(TypographyTokens.subheadline)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .accessibilityElement(children: .combine)

                    // 30-Day Rule Notice
                    KlymbCard(padding: LayoutTokens.paddingM) {
                        HStack(alignment: .top, spacing: LayoutTokens.spacingM) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.system(size: 24))
                                .foregroundStyle(ColorTokens.neonOrange)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("30-Day Cooldown Notice")
                                    .font(TypographyTokens.headline)
                                    .foregroundStyle(ColorTokens.textPrimary)

                                Text("To ensure leaderboard integrity, you can only switch your city arena once every 30 days.")
                                    .font(TypographyTokens.caption1)
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Notice: City selection is locked for 30 days to protect leaderboard integrity.")

                    // Search Field
                    HStack(spacing: LayoutTokens.spacingS) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(ColorTokens.textTertiary)

                        TextField("Search cities or country...", text: $viewModel.citySearchQuery)
                            .font(TypographyTokens.body)
                            .foregroundStyle(ColorTokens.textPrimary)
                            .autocorrectionDisabled(true)

                        if !viewModel.citySearchQuery.isEmpty {
                            Button {
                                viewModel.citySearchQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }
                    }
                    .padding(LayoutTokens.paddingM)
                    .background(ColorTokens.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusS))
                    .overlay(
                        RoundedRectangle(cornerRadius: LayoutTokens.radiusS)
                            .stroke(ColorTokens.borderSubtle, lineWidth: 1)
                    )

                    // City List
                    VStack(spacing: LayoutTokens.spacingS) {
                        ForEach(viewModel.filteredCities) { city in
                            CityRowCard(
                                city: city,
                                isSelected: viewModel.selectedCity?.id == city.id
                            ) {
                                HapticManager.shared.selection()
                                viewModel.selectedCity = city
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                .padding(.top, LayoutTokens.spacingL)
                .padding(.bottom, LayoutTokens.spacingXXL)
            }
            .scrollDismissesKeyboard(.immediately)

            // Fixed Bottom CTA
            VStack {
                Divider()
                    .background(ColorTokens.borderSubtle)

                PrimaryButton(
                    title: "Next: Choose Habits",
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

private struct CityRowCard: View {
    let city: CityItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            KlymbCard(
                glowColor: isSelected ? ColorTokens.electricCyan.opacity(0.25) : nil,
                padding: LayoutTokens.paddingM
            ) {
                HStack(spacing: LayoutTokens.spacingM) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? ColorTokens.electricCyan.opacity(0.2) : ColorTokens.backgroundSecondary)
                            .frame(width: 40, height: 40)

                        Image(systemName: city.country == "India" ? "building.2.fill" : "globe.americas.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(isSelected ? ColorTokens.electricCyan : ColorTokens.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(city.name)
                            .font(TypographyTokens.headline)
                            .foregroundStyle(ColorTokens.textPrimary)

                        Text(city.country)
                            .font(TypographyTokens.caption1)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(ColorTokens.electricCyan)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                    .stroke(isSelected ? ColorTokens.electricCyan : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(city.name), \(city.country)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}
