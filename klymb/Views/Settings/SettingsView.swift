//
//  SettingsView.swift
//  klymb
//
//  Settings, Profile Editing, City Cooldown, Habit Management,
//  and GDPR Data Export & Account Deletion.
//

import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    public init(container: AppContainerProtocol = AppContainer.mock) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: KlymbSpacing.lg) {
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

                    // 4. Push Notifications Navigation Link
                    NavigationLink {
                        NotificationPreferencesView()
                    } label: {
                        KlymbCard(padding: KlymbSpacing.lg) {
                            HStack(spacing: KlymbSpacing.md) {
                                Image(systemName: "bell.badge.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.KlymbAccent.soft)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Push Notifications")
                                        .font(Font.Klymb.bodySmall.weight(.semibold))
                                        .foregroundStyle(Color.KlymbText.primary)

                                    Text("Manage overtake alerts & streak reminders")
                                        .font(Font.Klymb.captionSmall)
                                        .foregroundStyle(Color.KlymbText.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.KlymbText.tertiary)
                            }
                        }
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
                .padding(.vertical, KlymbSpacing.md)
            }
            .background(Color.KlymbBackground.primary.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.KlymbBackground.primary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(Font.Klymb.bodySmall.weight(.semibold))
                    .foregroundStyle(Color.KlymbAccent.soft)
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
        VStack(alignment: .leading, spacing: KlymbSpacing.sm) {
            KlymbSectionHeader("Profile Details")

            KlymbCard(padding: KlymbSpacing.lg) {
                VStack(alignment: .leading, spacing: KlymbSpacing.md) {
                    Text("Avatar Crest")
                        .font(Font.Klymb.caption)
                        .foregroundStyle(Color.KlymbText.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: KlymbSpacing.md) {
                            ForEach(AvatarPreset.availablePresets) { preset in
                                let isSelected = viewModel.selectedAvatarPreset == preset.id
                                Button {
                                    viewModel.selectedAvatarPreset = preset.id
                                    HapticManager.selection()
                                } label: {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(isSelected ? Color.KlymbAccent.primaryMuted : Color.KlymbBackground.tertiary)
                                                .frame(width: 48, height: 48)

                                            Image(systemName: preset.iconName)
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundStyle(isSelected ? Color.KlymbAccent.soft : Color.KlymbText.secondary)
                                        }
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    isSelected ? Color.KlymbAccent.primary.opacity(0.75) : Color.clear,
                                                    lineWidth: 1.5
                                                )
                                        )

                                        Text(preset.displayName)
                                            .font(Font.Klymb.captionSmall)
                                            .foregroundStyle(isSelected ? Color.KlymbText.primary : Color.KlymbText.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    Divider().background(Color.KlymbBorder.subtle)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Display Name")
                            .font(Font.Klymb.caption)
                            .foregroundStyle(Color.KlymbText.secondary)

                        TextField("Display Name", text: $viewModel.displayName)
                            .font(Font.Klymb.body)
                            .foregroundStyle(Color.KlymbText.primary)
                            .padding(.horizontal, KlymbSpacing.md)
                            .frame(minHeight: 46)
                            .background(Color.KlymbBackground.tertiary)
                            .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous)
                                    .strokeBorder(Color.KlymbBorder.default, lineWidth: 1)
                            )
                    }

                    PrimaryButton(
                        "Save Profile Details",
                        icon: "checkmark",
                        tone: .bone,
                        isLoading: viewModel.isSavingProfile
                    ) {
                        Task {
                            await viewModel.saveProfile()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 2. City Selection Section
private struct CitySelectionSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: KlymbSpacing.sm) {
            KlymbSectionHeader("League & City")

            KlymbCard(padding: KlymbSpacing.lg) {
                VStack(alignment: .leading, spacing: KlymbSpacing.md) {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.cityCooldown.canChangeCity ? "checkmark.seal.fill" : "lock.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(
                                viewModel.cityCooldown.canChangeCity ? Color.KlymbSemantic.success : Color.KlymbSemantic.warning
                            )

                        Text(
                            viewModel.cityCooldown.canChangeCity
                                ? "City change eligible (30-day cooldown resets upon change)"
                                : "Cooldown active: next change in \(viewModel.cityCooldown.cooldownDaysRemaining) days"
                        )
                        .font(Font.Klymb.caption)
                        .foregroundStyle(
                            viewModel.cityCooldown.canChangeCity ? Color.KlymbSemantic.success : Color.KlymbSemantic.warning
                        )

                        Spacer()
                    }
                    .padding(KlymbSpacing.sm)
                    .background(
                        (viewModel.cityCooldown.canChangeCity ? Color.KlymbSemantic.success : Color.KlymbSemantic.warning)
                            .opacity(0.08)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.sm, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Current City Leaderboard")
                            .font(Font.Klymb.caption)
                            .foregroundStyle(Color.KlymbText.secondary)

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
                                    .foregroundStyle(Color.KlymbAccent.soft)

                                Text(
                                    viewModel.cities.first(where: { $0.id == viewModel.selectedCityId })?.name ?? "Select City"
                                )
                                .font(Font.Klymb.headline)
                                .foregroundStyle(Color.KlymbText.primary)

                                Spacer()

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.KlymbText.tertiary)
                            }
                            .padding(.horizontal, KlymbSpacing.md)
                            .frame(minHeight: 46)
                            .background(Color.KlymbBackground.tertiary)
                            .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous)
                                    .strokeBorder(Color.KlymbBorder.default, lineWidth: 1)
                            )
                        }
                        .disabled(!viewModel.cityCooldown.canChangeCity || viewModel.isSavingCity)
                        .opacity(viewModel.cityCooldown.canChangeCity ? 1.0 : 0.6)
                    }
                }
            }
        }
    }
}

// MARK: - 3. Habits Selection Section
private struct HabitsSelectionSection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: KlymbSpacing.sm) {
            KlymbSectionHeader(
                "Daily Disciplines",
                trailingText: "\(viewModel.selectedHabitIds.count)/\(viewModel.habits.count) • MIN 3",
                trailingColor: viewModel.selectedHabitIds.count >= 3 ? Color.KlymbAccent.soft : Color.KlymbSemantic.error
            )

            KlymbGroupedSurface {
                ForEach(Array(viewModel.habits.enumerated()), id: \.element.id) { index, habit in
                    if index > 0 {
                        Divider()
                            .background(Color.KlymbBorder.subtle)
                            .padding(.leading, 52)
                    }
                    Button {
                        viewModel.toggleHabit(id: habit.id)
                    } label: {
                        let isSelected = viewModel.selectedHabitIds.contains(habit.id)
                        HStack(spacing: KlymbSpacing.md) {
                            Image(systemName: KlymbIconCatalog.habitIcon(for: habit.key))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.KlymbAccent.soft : Color.KlymbText.secondary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(habit.displayName)
                                    .font(Font.Klymb.bodySmall.weight(.semibold))
                                    .foregroundStyle(Color.KlymbText.primary)

                                Text("Cap: \(habit.dailyKPCap) KP/\(habit.unit)")
                                    .font(Font.Klymb.captionSmall)
                                    .foregroundStyle(Color.KlymbText.tertiary)
                            }

                            Spacer()

                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.KlymbSemantic.success : Color.KlymbText.tertiary)
                        }
                        .padding(.horizontal, KlymbSpacing.lg)
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Divider().background(Color.KlymbBorder.subtle)

                PrimaryButton(
                    "Update Active Habits",
                    icon: "checkmark",
                    tone: .bone,
                    isLoading: viewModel.isSavingHabits,
                    isEnabled: viewModel.selectedHabitIds.count >= 3
                ) {
                    Task {
                        await viewModel.saveHabits()
                    }
                }
                .padding(KlymbSpacing.md)
            }
        }
    }
}

// MARK: - 5. Privacy & Data (GDPR) Section
private struct PrivacySection: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: KlymbSpacing.sm) {
            KlymbSectionHeader("Data & Privacy (GDPR)")

            KlymbGroupedSurface {
                Button {
                    Task {
                        await viewModel.exportData()
                    }
                } label: {
                    HStack(spacing: KlymbSpacing.md) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.KlymbAccent.soft)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export My Data")
                                .font(Font.Klymb.bodySmall.weight(.semibold))
                                .foregroundStyle(Color.KlymbText.primary)

                            Text("Download archive of activities, KP ledger, and profile in JSON")
                                .font(Font.Klymb.captionSmall)
                                .foregroundStyle(Color.KlymbText.secondary)
                        }

                        Spacer()

                        if viewModel.isExportingData {
                            ProgressView()
                                .tint(Color.KlymbAccent.primary)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.KlymbText.tertiary)
                        }
                    }
                    .padding(.horizontal, KlymbSpacing.lg)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isExportingData)

                Divider()
                    .background(Color.KlymbBorder.subtle)
                    .padding(.leading, 52)

                Button {
                    viewModel.showDeleteAlert = true
                } label: {
                    HStack(spacing: KlymbSpacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.KlymbSemantic.error)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Delete Account")
                                .font(Font.Klymb.bodySmall.weight(.semibold))
                                .foregroundStyle(Color.KlymbSemantic.error)

                            Text("30-day grace period before irrevocable purge.")
                                .font(Font.Klymb.captionSmall)
                                .foregroundStyle(Color.KlymbText.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.KlymbSemantic.error.opacity(0.6))
                    }
                    .padding(.horizontal, KlymbSpacing.lg)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 6. Legal & App Version Section
private struct LegalSection: View {
    var body: some View {
        VStack(spacing: KlymbSpacing.sm) {
            HStack(spacing: KlymbSpacing.lg) {
                Link("Privacy Policy", destination: URL(string: "https://klymb.app/privacy")!)
                    .font(Font.Klymb.caption)
                    .foregroundStyle(Color.KlymbAccent.soft)

                Text("•")
                    .foregroundStyle(Color.KlymbText.tertiary)

                Link("Terms of Service", destination: URL(string: "https://klymb.app/terms")!)
                    .font(Font.Klymb.caption)
                    .foregroundStyle(Color.KlymbAccent.soft)
            }
            .padding(.top, KlymbSpacing.xs)

            Text("Klymb iOS • v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") (Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                .font(Font.Klymb.captionSmall)
                .foregroundStyle(Color.KlymbText.tertiary)
        }
    }
}

// MARK: - Feedback Banner
private struct FeedbackBanner: View {
    let message: String
    let isSuccess: Bool
    let onDismiss: () -> Void

    var body: some View {
        let color = isSuccess ? Color.KlymbSemantic.success : Color.KlymbSemantic.error
        HStack(spacing: KlymbSpacing.md) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(color)

            Text(message)
                .font(Font.Klymb.caption.weight(.semibold))
                .foregroundStyle(Color.KlymbText.primary)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.KlymbText.tertiary)
            }
        }
        .padding(KlymbSpacing.md)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
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
