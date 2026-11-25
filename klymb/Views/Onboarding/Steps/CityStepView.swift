//
//  CityStepView.swift
//  klymb
//
//  Step 3: City Arena selection with 30-day cooldown notice and grouped city rows.
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
                    VStack(alignment: .leading, spacing: LayoutTokens.spacingS) {
                        Text("Choose your arena")
                            .font(Font.Klymb.titleLarge)
                            .foregroundStyle(Color.KlymbText.primary)

                        Text("Represent and compete for your city on local and regional leaderboards.")
                            .font(Font.Klymb.bodySmall)
                            .foregroundStyle(Color.KlymbText.secondary)
                    }
                    .accessibilityElement(children: .combine)

                    // Compact 30-Day Rule Notice
                    HStack(alignment: .top, spacing: KlymbSpacing.md) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.KlymbSemantic.warning)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("30-Day Cooldown")
                                .font(Font.Klymb.caption.weight(.semibold))
                                .foregroundStyle(Color.KlymbText.primary)

                            Text("To protect leaderboard integrity, you can switch cities once every 30 days.")
                                .font(Font.Klymb.captionSmall)
                                .foregroundStyle(Color.KlymbText.secondary)
                        }
                    }
                    .padding(KlymbSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.KlymbSemantic.warning.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous)
                            .strokeBorder(Color.KlymbSemantic.warning.opacity(0.25), lineWidth: 1)
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Notice: City selection is locked for 30 days to protect leaderboard integrity.")

                    // Search Field
                    HStack(spacing: LayoutTokens.spacingS) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.KlymbText.tertiary)

                        TextField("Search cities or country...", text: $viewModel.citySearchQuery)
                            .font(Font.Klymb.body)
                            .foregroundStyle(Color.KlymbText.primary)
                            .autocorrectionDisabled(true)

                        if !viewModel.citySearchQuery.isEmpty {
                            Button {
                                viewModel.citySearchQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.KlymbText.tertiary)
                            }
                        }
                    }
                    .padding(.horizontal, KlymbSpacing.md)
                    .frame(minHeight: 46)
                    .background(Color.KlymbBackground.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous)
                            .strokeBorder(Color.KlymbBorder.default, lineWidth: 1)
                    )

                    // Grouped City List
                    KlymbGroupedSurface {
                        ForEach(Array(viewModel.filteredCities.enumerated()), id: \.element.id) { index, city in
                            if index > 0 {
                                Divider()
                                    .background(Color.KlymbBorder.subtle)
                                    .padding(.leading, 48)
                            }
                            CityRowCard(
                                city: city,
                                isSelected: viewModel.selectedCity?.id == city.id
                            ) {
                                HapticManager.shared.selection()
                                viewModel.selectedCity = city
                            }
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                .padding(.top, LayoutTokens.spacingM)
                .padding(.bottom, LayoutTokens.spacingXXL)
            }
            .scrollDismissesKeyboard(.immediately)

            // Fixed Bottom CTA
            VStack(spacing: 0) {
                Divider().background(Color.KlymbBorder.subtle)

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
            .background(Color.KlymbBackground.primary)
        }
    }
}

private struct CityRowCard: View {
    let city: CityItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KlymbSpacing.md) {
                Image(systemName: city.country == "India" ? "building.2" : "globe.americas")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.KlymbAccent.soft : Color.KlymbText.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(city.name)
                        .font(Font.Klymb.headline)
                        .foregroundStyle(Color.KlymbText.primary)

                    Text(city.country)
                        .font(Font.Klymb.caption)
                        .foregroundStyle(Color.KlymbText.tertiary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.KlymbAccent.soft : Color.KlymbText.tertiary)
            }
            .padding(.horizontal, KlymbSpacing.lg)
            .padding(.vertical, 14)
            .background(isSelected ? Color.KlymbAccent.primaryMuted : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(city.name), \(city.country)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
    }
}
