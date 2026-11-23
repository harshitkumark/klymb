//
//  SettingsView.swift
//  klymb
//
//  Settings, Profile Editing, City Cooldown, Habit Management,
//  and GDPR Data Export & Account Deletion (PRD §F15 & Design System §9.11).
//  Follows AGENTS.md Rules 15, 18.
//

import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(container: AppContainerProtocol = AppContainer.mock) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LayoutTokens.spacingL) {
                    // Success / Error Banner
                    if let msg = viewModel.successMessage {
                        FeedbackBanner(message: msg, isSuccess: true) {
                            viewModel.successMessage = nil
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    }

                    if let err = viewModel.errorMessage {
                        FeedbackBanner(message: err, isSuccess: false) {
                            viewModel.errorMessage = nil
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    }

                    // 1. Profile Details & Avatar
                    ProfileEditSection(viewModel: viewModel)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    // 2. City & 30-Day Cooldown
                    CitySelectionSection(viewModel: viewModel)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    // 3. Daily Habits Selection
                    HabitsSelectionSection(viewModel: viewModel)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    // 4. Notifications Navigation Link
                    NavigationLink {
                        NotificationPreferencesView()
                    } label: {
                        HStack(spacing: LayoutTokens.spacingM) {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(ColorTokens.electricCyan)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Push Notifications")
                                    .font(TypographyTokens.subheadline.bold())
                                    .foregroundStyle(ColorTokens.textPrimary)

                                Text("Manage overtake alerts & streak reminders")
                                    .font(TypographyTokens.caption1)
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        .padding(LayoutTokens.paddingM)
                        .background(
                            RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                                .fill(ColorTokens.backgroundSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                                .strokeBorder(ColorTokens.borderSubtle, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    // 5. Privacy & Data (GDPR)
                    PrivacySection(viewModel: viewModel)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    // 6. Legal & App Version
                    LegalSection()
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                    Spacer(minLength: 40)
                }
                .padding(.vertical, LayoutTokens.spacingM)
            }
            .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ColorTokens.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(TypographyTokens.subheadline.bold())
                    .foregroundStyle(ColorTokens.electricCyan)
                }
            }
            .task {
                await viewModel.loadSettings()
            }
            .sheet(isPresented: $viewModel.showExportShareSheet) {
                if let export = viewModel.exportFile {
                    ActivityShareSheet(activityItems: [export.jsonString])
                }
            }
            .alert("Request Account Deletion?", isPresented: $viewModel.showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete My Account", role: .destructive) {
                    Task {
                        await viewModel.requestAccountDeletion()
                        await appState.signOut()
                        dismiss()
                    }
                }
            } message: {
                Text("Your account will enter a 30-day grace period. During this period, your profile and leaderboard stats are frozen. You can log back in at any time to cancel.")
            }
        }
    }
}

// MARK: - 1. Profile Edit Section
private struct ProfileEditSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutTokens.spacingM) {
            Text("PROFILE DETAILS")
                .font(TypographyTokens.caption1.bold())
                .foregroundStyle(ColorTokens.textTertiary)

            VStack(alignment: .leading, spacing: LayoutTokens.spacingM) {
                // Avatar Preset Selector
                Text("Choose Avatar Crest")
                    .font(TypographyTokens.caption2.weight(.semibold))
                    .foregroundStyle(ColorTokens.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LayoutTokens.spacingM) {
                        ForEach(AvatarPreset.availablePresets) { preset in
                            Button {
                                viewModel.selectedAvatarPreset = preset.id
                                HapticManager.selection()
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(ColorTokens.backgroundTertiary)
                                            .frame(width: 52, height: 52)

                                        Image(systemName: preset.iconName)
                                            .font(.system(size: 24))
                                            .foregroundStyle(
                                                viewModel.selectedAvatarPreset == preset.id ?
                                                ColorTokens.electricCyan : ColorTokens.textTertiary
                                            )
                                    }
                                    .overlay(
                                        Circle()
                                            .strokeBorder(
                                                viewModel.selectedAvatarPreset == preset.id ?
                                                ColorTokens.electricCyan : Color.clear,
                                                lineWidth: 2
                                            )
                                    )

                                    Text(preset.displayName)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(
                                            viewModel.selectedAvatarPreset == preset.id ?
                                            ColorTokens.textPrimary : ColorTokens.textTertiary
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Divider()
                    .background(ColorTokens.borderSubtle)

                // Display Name Editor
                VStack(alignment: .leading, spacing: 6) {
                    Text("Display Name")
                        .font(TypographyTokens.caption2.weight(.semibold))
                        .foregroundStyle(ColorTokens.textSecondary)

                    TextField("Display Name", text: $viewModel.displayName)
                        .font(TypographyTokens.body)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .padding(LayoutTokens.paddingM)
                        .background(ColorTokens.backgroundTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusM))
                        .overlay(
                            RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                                .strokeBorder(ColorTokens.borderSubtle, lineWidth: 1)
                        )
                }

                // Save Profile Button
                Button {
                    Task {
                        await viewModel.saveProfile()
                    }
                } label: {
                    HStack {
                        if viewModel.isSavingProfile {
                            ProgressView()
                                .tint(Color.black)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                            Text("Save Profile Details")
                                .font(TypographyTokens.subheadline.bold())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(ColorTokens.electricCyan)
                    .foregroundStyle(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusM))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSavingProfile)
            }
            .padding(LayoutTokens.paddingM)
            .background(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                    .fill(ColorTokens.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                    .strokeBorder(ColorTokens.borderSubtle, lineWidth: 1)
            )
        }
    }
}

// MARK: - 2. City Selection Section
private struct CitySelectionSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutTokens.spacingM) {
            Text("LEAGUE & CITY")
                .font(TypographyTokens.caption1.bold())
                .foregroundStyle(ColorTokens.textTertiary)

            VStack(alignment: .leading, spacing: LayoutTokens.spacingM) {
                // Cooldown Status Badge
                HStack(spacing: 8) {
                    Image(systemName: viewModel.cityCooldown.canChangeCity ? "checkmark.seal.fill" : "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(
                            viewModel.cityCooldown.canChangeCity ? ColorTokens.neonGreen : ColorTokens.neonOrange
                        )

                    Text(
                        viewModel.cityCooldown.canChangeCity ?
                        "City change eligible (30-day cooldown resets upon change)" :
                        "Cooldown active: next change in \(viewModel.cityCooldown.cooldownDaysRemaining) days"
                    )
                    .font(TypographyTokens.caption1.weight(.medium))
                    .foregroundStyle(
                        viewModel.cityCooldown.canChangeCity ? ColorTokens.neonGreen : ColorTokens.neonOrange
                    )

                    Spacer()
                }
                .padding(LayoutTokens.paddingS)
                .background(
                    (viewModel.cityCooldown.canChangeCity ? ColorTokens.neonGreen : ColorTokens.neonOrange)
                        .opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusM))

                // City Picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current City Leaderboard")
                        .font(TypographyTokens.caption2.weight(.semibold))
                        .foregroundStyle(ColorTokens.textSecondary)

                    Menu {
                        ForEach(viewModel.cities) { city in
                            Button {
                                Task {
                                    await viewModel.changeCity(newCityId: city.id)
                                }
                            } label: {
                                HStack {
                                    Text("\(city.name), \(city.country)")
                                    if city.id == viewModel.selectedCityId {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(ColorTokens.electricCyan)

                            Text(
                                viewModel.cities.first(where: { $0.id == viewModel.selectedCityId })?.name ?? "Select City"
                            )
                            .font(TypographyTokens.body.bold())
                            .foregroundStyle(ColorTokens.textPrimary)

                            Spacer()

                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        .padding(LayoutTokens.paddingM)
                        .background(ColorTokens.backgroundTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusM))
                        .overlay(
                            RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                                .strokeBorder(ColorTokens.borderSubtle, lineWidth: 1)
                        )
                    }
                    .disabled(!viewModel.cityCooldown.canChangeCity || viewModel.isSavingCity)
                    .opacity(viewModel.cityCooldown.canChangeCity ? 1.0 : 0.6)
                }
            }
            .padding(LayoutTokens.paddingM)
            .background(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                    .fill(ColorTokens.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                    .strokeBorder(ColorTokens.borderSubtle, lineWidth: 1)
            )
        }
    }
}

// MARK: - 3. Habits Selection Section
private struct HabitsSelectionSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutTokens.spacingM) {
            HStack {
                Text("DAILY HABIT DISCIPLINES")
                    .font(TypographyTokens.caption1.bold())
                    .foregroundStyle(ColorTokens.textTertiary)

                Spacer()

                Text("Selected (\(viewModel.selectedHabitIds.count)/\(viewModel.habits.count)) • Min 3")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(
                        viewModel.selectedHabitIds.count >= 3 ? ColorTokens.electricCyan : ColorTokens.neonRed
                    )
            }

            VStack(spacing: 0) {
                ForEach(viewModel.habits) { habit in
                    Button {
                        viewModel.toggleHabit(id: habit.id)
                    } label: {
                        HStack(spacing: LayoutTokens.spacingM) {
                            Image(systemName: habitIcon(for: habit.key))
                                .font(.system(size: 18))
                                .foregroundStyle(ColorTokens.electricCyan)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(habit.displayName)
                                    .font(TypographyTokens.subheadline.bold())
                                    .foregroundStyle(ColorTokens.textPrimary)

                                Text("Cap: \(habit.dailyKPCap) KP/\(habit.unit)")
                                    .font(TypographyTokens.caption2)
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }

                            Spacer()

                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        viewModel.selectedHabitIds.contains(habit.id) ?
                                        ColorTokens.electricCyan : ColorTokens.borderSubtle,
                                        lineWidth: 2
                                    )
                                    .frame(width: 24, height: 24)

                                if viewModel.selectedHabitIds.contains(habit.id) {
                                    Circle()
                                        .fill(ColorTokens.electricCyan)
                                        .frame(width: 14, height: 14)
                                }
                            }
                        }
                        .padding(LayoutTokens.paddingM)
                    }
                    .buttonStyle(.plain)

                    if habit.id != viewModel.habits.last?.id {
                        Divider()
                            .background(ColorTokens.borderSubtle)
                            .padding(.leading, 56)
                    }
                }

                // Save Habits Button
                Button {
                    Task {
                        await viewModel.saveHabits()
                    }
                } label: {
                    HStack {
                        if viewModel.isSavingHabits {
                            ProgressView()
                                .tint(Color.black)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Update Active Habits")
                                .font(TypographyTokens.subheadline.bold())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(ColorTokens.electricCyan)
                    .foregroundStyle(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusM))
                    .padding(LayoutTokens.paddingM)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectedHabitIds.count < 3 || viewModel.isSavingHabits)
                .opacity(viewModel.selectedHabitIds.count >= 3 ? 1.0 : 0.5)
            }
            .background(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                    .fill(ColorTokens.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                    .strokeBorder(ColorTokens.borderSubtle, lineWidth: 1)
            )
        }
    }

    private func habitIcon(for key: String) -> String {
        switch key {
        case "steps": return "figure.walk"
        case "running": return "figure.run"
        case "walking_distance": return "figure.walk.motion"
        case "workout": return "dumbbell.fill"
        case "hydration": return "drop.fill"
        case "sleep": return "bed.double.fill"
        case "mindfulness": return "brain.head.profile"
        default: return "sparkles"
        }
    }
}

// MARK: - 5. Privacy & Data (GDPR) Section
private struct PrivacySection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: LayoutTokens.spacingM) {
            Text("DATA & PRIVACY (GDPR)")
                .font(TypographyTokens.caption1.bold())
                .foregroundStyle(ColorTokens.textTertiary)

            VStack(spacing: LayoutTokens.spacingM) {
                // Export My Data Button
                Button {
                    Task {
                        await viewModel.exportData()
                    }
                } label: {
                    HStack(spacing: LayoutTokens.spacingM) {
                        Image(systemName: "square.and.arrow.up.fill")
                            .foregroundStyle(ColorTokens.electricCyan)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export My Data")
                                .font(TypographyTokens.subheadline.bold())
                                .foregroundStyle(ColorTokens.textPrimary)

                            Text("Download complete archive of activities, KP ledger, and profile in JSON")
                                .font(TypographyTokens.caption2)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }

                        Spacer()

                        if viewModel.isExportingData {
                            ProgressView()
                                .tint(ColorTokens.electricCyan)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                    .padding(LayoutTokens.paddingM)
                    .background(ColorTokens.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusM))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isExportingData)

                // Delete Account Button
                Button {
                    viewModel.showDeleteAlert = true
                } label: {
                    HStack(spacing: LayoutTokens.spacingM) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(ColorTokens.neonRed)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete Account")
                                .font(TypographyTokens.subheadline.bold())
                                .foregroundStyle(ColorTokens.neonRed)

                            Text("30-day grace period. Irrevocably purges all data after 30 days.")
                                .font(TypographyTokens.caption2)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ColorTokens.neonRed.opacity(0.6))
                    }
                    .padding(LayoutTokens.paddingM)
                    .background(ColorTokens.neonRed.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusM))
                    .overlay(
                        RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                            .strokeBorder(ColorTokens.neonRed.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(LayoutTokens.paddingM)
            .background(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                    .fill(ColorTokens.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                    .strokeBorder(ColorTokens.borderSubtle, lineWidth: 1)
            )
        }
    }
}

// MARK: - 6. Legal & App Version Section
private struct LegalSection: View {
    var body: some View {
        VStack(spacing: LayoutTokens.spacingS) {
            HStack(spacing: LayoutTokens.spacingL) {
                Link("Privacy Policy", destination: URL(string: "https://klymb.app/privacy")!)
                    .font(TypographyTokens.caption1)
                    .foregroundStyle(ColorTokens.electricCyan)

                Text("•")
                    .foregroundStyle(ColorTokens.textTertiary)

                Link("Terms of Service", destination: URL(string: "https://klymb.app/terms")!)
                    .font(TypographyTokens.caption1)
                    .foregroundStyle(ColorTokens.electricCyan)
            }
            .padding(.top, LayoutTokens.spacingS)

            Text("Klymb iOS • v1.0.0 (Build 42)")
                .font(TypographyTokens.caption2)
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }
}

// MARK: - Feedback Banner
private struct FeedbackBanner: View {
    let message: String
    let isSuccess: Bool
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: LayoutTokens.spacingM) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isSuccess ? ColorTokens.neonGreen : ColorTokens.neonRed)

            Text(message)
                .font(TypographyTokens.caption1.bold())
                .foregroundStyle(ColorTokens.textPrimary)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
        .padding(LayoutTokens.paddingM)
        .background(
            (isSuccess ? ColorTokens.neonGreen : ColorTokens.neonRed).opacity(0.12)
        )
        .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusM))
        .overlay(
            RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                .strokeBorder((isSuccess ? ColorTokens.neonGreen : ColorTokens.neonRed).opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - UIKit Activity Share Sheet
public struct ActivityShareSheet: UIViewControllerRepresentable {
    public let activityItems: [Any]

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
