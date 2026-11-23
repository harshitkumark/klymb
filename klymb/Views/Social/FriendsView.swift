//
//  FriendsView.swift
//  klymb
//
//  Friends & Social Tab: Athlete search, incoming/outgoing friend requests,
//  and friend cheering (PRD §F11 & Design System §9.10).
//  Follows AGENTS.md Rules 2, 15, 18.
//

import SwiftUI

public struct FriendsView: View {
    @StateObject private var viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(container: AppContainerProtocol = AppContainer.mock) {
        _viewModel = StateObject(wrappedValue: FriendsViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: LayoutTokens.spacingM) {
                // 1. Social Tabs Switcher
                FriendsTabSelector(
                    selectedTab: viewModel.selectedTab,
                    requestsCount: viewModel.incomingRequests.count,
                    onSelect: { tab in
                        viewModel.selectedTab = tab
                        HapticManager.selection()
                    }
                )
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                .padding(.top, LayoutTokens.spacingS)

                // 2. Search Field (Always for Discover, or toggleable)
                if viewModel.selectedTab == .search {
                    SearchBarView(text: $viewModel.searchQuery)
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                }

                // 3. Tab Content
                ScrollView {
                    VStack(spacing: LayoutTokens.spacingM) {
                        switch viewModel.selectedTab {
                        case .friends:
                            if viewModel.friends.isEmpty && !viewModel.isLoading {
                                EmptyFriendsView(
                                    title: "No Friends Added Yet",
                                    subtitle: "Connect with athletes in your city to track progress and cheer each other on.",
                                    buttonTitle: "Find Athletes",
                                    action: { viewModel.selectedTab = .search }
                                )
                                .padding(.top, 40)
                            } else {
                                ForEach(viewModel.friends) { friend in
                                    FriendCard(
                                        friend: friend,
                                        isCheered: viewModel.cheeredUserIds.contains(friend.id),
                                        onCheer: { Task { await viewModel.cheer(user: friend) } },
                                        onTap: { viewModel.selectFriend(friend) }
                                    )
                                }
                            }

                        case .requests:
                            if viewModel.incomingRequests.isEmpty && !viewModel.isLoading {
                                EmptyFriendsView(
                                    title: "No Pending Requests",
                                    subtitle: "You're all caught up! New friend requests will appear here.",
                                    buttonTitle: "Discover Athletes",
                                    action: { viewModel.selectedTab = .search }
                                )
                                .padding(.top, 40)
                            } else {
                                ForEach(viewModel.incomingRequests) { request in
                                    RequestCard(
                                        request: request,
                                        onAccept: { Task { await viewModel.acceptRequest(from: request) } },
                                        onDecline: { Task { await viewModel.declineRequest(from: request) } },
                                        onTap: { viewModel.selectFriend(request) }
                                    )
                                }
                            }

                        case .search:
                            if viewModel.searchResults.isEmpty && !viewModel.isLoading {
                                EmptyFriendsView(
                                    title: "Find Your Rivals & Squad",
                                    subtitle: "Search by username or name to send friend requests.",
                                    buttonTitle: nil,
                                    action: nil
                                )
                                .padding(.top, 40)
                            } else {
                                ForEach(viewModel.searchResults) { user in
                                    DiscoverUserCard(
                                        user: user,
                                        onAddFriend: { Task { await viewModel.sendRequest(to: user) } },
                                        onTap: { viewModel.selectFriend(user) }
                                    )
                                }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    .padding(.top, LayoutTokens.spacingS)
                    .padding(.bottom, LayoutTokens.spacingXXL)
                }
                .refreshable {
                    await viewModel.loadData()
                }
            }
            .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ColorTokens.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(ColorTokens.electricCyan)
                }
            }
            .task {
                await viewModel.loadData()
            }
            .sheet(item: $viewModel.selectedFriend) { friend in
                FriendProfileModal(
                    friend: friend,
                    isCheered: viewModel.cheeredUserIds.contains(friend.id),
                    onCheer: { Task { await viewModel.cheer(user: friend) } },
                    onClose: { viewModel.dismissFriendDetail() }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - 1. Friends Tab Selector
private struct FriendsTabSelector: View {
    let selectedTab: FriendsTab
    let requestsCount: Int
    let onSelect: (FriendsTab) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FriendsTab.allCases) { tab in
                let isSelected = (tab == selectedTab)

                Button {
                    onSelect(tab)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 12, weight: .bold))

                        Text(tab.rawValue)
                            .font(TypographyTokens.caption1.weight(.semibold))

                        if tab == .requests && requestsCount > 0 {
                            Text("\(requestsCount)")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(Color.black)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(ColorTokens.electricCyan)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? ColorTokens.backgroundTertiary : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusM))
                    .overlay(
                        RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                            .strokeBorder(isSelected ? ColorTokens.electricCyan.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
                    .foregroundStyle(isSelected ? ColorTokens.electricCyan : ColorTokens.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tab.rawValue) tab")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(ColorTokens.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusL))
    }
}

// MARK: - 2. Search Bar View
private struct SearchBarView: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: LayoutTokens.spacingS) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ColorTokens.textTertiary)

            TextField("Search by username or name...", text: $text)
                .font(TypographyTokens.subheadline)
                .foregroundStyle(ColorTokens.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, LayoutTokens.paddingM)
        .padding(.vertical, 10)
        .background(ColorTokens.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: LayoutTokens.radiusM))
        .overlay(
            RoundedRectangle(cornerRadius: LayoutTokens.radiusM)
                .strokeBorder(ColorTokens.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - 3. Friend Card
private struct FriendCard: View {
    let friend: FriendItem
    let isCheered: Bool
    let onCheer: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: LayoutTokens.spacingM) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(ColorTokens.backgroundTertiary)
                        .frame(width: 46, height: 46)

                    Image(systemName: friend.avatarIconName)
                        .font(.system(size: 20))
                        .foregroundStyle(friend.rankTier.tierColor)
                }
                .overlay(
                    Circle()
                        .strokeBorder(friend.rankTier.tierColor.opacity(0.6), lineWidth: 1.5)
                )

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(friend.titleDisplay)
                            .font(TypographyTokens.subheadline.bold())
                            .foregroundStyle(ColorTokens.textPrimary)

                        if friend.streak > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 10))
                                Text("\(friend.streak)")
                                    .font(.system(size: 10, weight: .heavy))
                            }
                            .foregroundStyle(ColorTokens.neonOrange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(ColorTokens.neonOrange.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 6) {
                        Text("\(friend.totalKP) KP")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(ColorTokens.electricCyan)

                        if let city = friend.cityName {
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundStyle(ColorTokens.textTertiary)
                            Text(city)
                                .font(TypographyTokens.caption2)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                    }
                }

                Spacer()

                // Cheer button
                Button {
                    onCheer()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCheered ? "flame.fill" : "hands.clap.fill")
                            .font(.system(size: 12))
                        Text(isCheered ? "Cheered" : "Cheer")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isCheered ? ColorTokens.neonOrange.opacity(0.2) : ColorTokens.electricCyan.opacity(0.15))
                    .foregroundStyle(isCheered ? ColorTokens.neonOrange : ColorTokens.electricCyan)
                    .clipShape(Capsule())
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
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(friend.titleDisplay), \(friend.totalKP) KP, streak of \(friend.streak) days")
    }
}

// MARK: - 4. Request Card
private struct RequestCard: View {
    let request: FriendItem
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: LayoutTokens.spacingM) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(ColorTokens.backgroundTertiary)
                        .frame(width: 44, height: 44)

                    Image(systemName: request.avatarIconName)
                        .font(.system(size: 20))
                        .foregroundStyle(request.rankTier.tierColor)
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.titleDisplay)
                        .font(TypographyTokens.subheadline.bold())
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("\(request.totalKP) KP • \(request.cityName ?? "Athlete")")
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Spacer()

                // Actions: Decline & Accept
                HStack(spacing: 8) {
                    Button {
                        onDecline()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ColorTokens.textTertiary)
                            .padding(8)
                            .background(ColorTokens.backgroundTertiary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onAccept()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.black)
                            .padding(8)
                            .background(ColorTokens.electricCyan)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(LayoutTokens.paddingM)
            .background(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                    .fill(ColorTokens.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LayoutTokens.radiusL)
                    .strokeBorder(ColorTokens.electricCyan.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 5. Discover User Card
private struct DiscoverUserCard: View {
    let user: FriendItem
    let onAddFriend: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: LayoutTokens.spacingM) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(ColorTokens.backgroundTertiary)
                        .frame(width: 44, height: 44)

                    Image(systemName: user.avatarIconName)
                        .font(.system(size: 20))
                        .foregroundStyle(user.rankTier.tierColor)
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.titleDisplay)
                        .font(TypographyTokens.subheadline.bold())
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("\(user.totalKP) KP • \(user.cityName ?? "Global")")
                        .font(TypographyTokens.caption2)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Spacer()

                // Status Button
                if user.status == .friends {
                    Text("Friends")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ColorTokens.neonGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ColorTokens.neonGreen.opacity(0.12))
                        .clipShape(Capsule())
                } else if user.status == .pendingSent {
                    Text("Sent")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ColorTokens.backgroundTertiary)
                        .clipShape(Capsule())
                } else {
                    Button {
                        onAddFriend()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("Add")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ColorTokens.electricCyan)
                        .foregroundStyle(Color.black)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
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
        .buttonStyle(.plain)
    }
}

// MARK: - 6. Friend Profile Modal
private struct FriendProfileModal: View {
    let friend: FriendItem
    let isCheered: Bool
    let onCheer: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: LayoutTokens.spacingL) {
                // Large Avatar
                ZStack {
                    Circle()
                        .fill(ColorTokens.backgroundSecondary)
                        .frame(width: 88, height: 88)

                    Image(systemName: friend.avatarIconName)
                        .font(.system(size: 40))
                        .foregroundStyle(friend.rankTier.tierColor)
                }
                .overlay(
                    Circle()
                        .strokeBorder(friend.rankTier.tierColor.opacity(0.8), lineWidth: 2.5)
                )
                .padding(.top, LayoutTokens.spacingM)

                // Names & City
                VStack(spacing: 4) {
                    Text(friend.titleDisplay)
                        .font(TypographyTokens.title2)
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("@\(friend.username)")
                        .font(TypographyTokens.subheadline)
                        .foregroundStyle(ColorTokens.textTertiary)

                    if let city = friend.cityName {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 12))
                            Text(city)
                                .font(TypographyTokens.caption1)
                        }
                        .foregroundStyle(ColorTokens.electricCyan)
                        .padding(.top, 4)
                    }
                }

                // Stats Grid
                HStack(spacing: LayoutTokens.spacingM) {
                    StatTile(
                        icon: "bolt.fill",
                        value: "\(friend.totalKP) KP",
                        label: "TOTAL KP",
                        valueColor: ColorTokens.electricCyan
                    )

                    StatTile(
                        icon: "flame.fill",
                        value: "\(friend.streak) Days",
                        label: "STREAK",
                        valueColor: ColorTokens.neonOrange
                    )

                    StatTile(
                        icon: friend.rankTier.iconName,
                        value: friend.rankTier.rawValue.components(separatedBy: " ").first ?? "Rank",
                        label: "TIER",
                        valueColor: friend.rankTier.tierColor
                    )
                }
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                Spacer()

                // Action: Cheer
                PrimaryButton(
                    isCheered ? "Cheered! 🔥" : "Cheer Athlete",
                    icon: isCheered ? "flame.fill" : "hands.clap.fill",
                    action: {
                        onCheer()
                    }
                )
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                .padding(.bottom, LayoutTokens.spacingM)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTokens.backgroundPrimary.ignoresSafeArea())
            .navigationTitle("Athlete Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onClose)
                        .foregroundStyle(ColorTokens.electricCyan)
                }
            }
        }
    }
}

// MARK: - 7. Empty State View
private struct EmptyFriendsView: View {
    let title: String
    let subtitle: String
    let buttonTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: LayoutTokens.spacingM) {
            Image(systemName: "person.2.slash.fill")
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.textTertiary)

            Text(title)
                .font(TypographyTokens.headline)
                .foregroundStyle(ColorTokens.textPrimary)

            Text(subtitle)
                .font(TypographyTokens.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)

            if let btn = buttonTitle, let act = action {
                Button(action: act) {
                    Text(btn)
                        .font(TypographyTokens.caption1.bold())
                        .foregroundStyle(ColorTokens.electricCyan)
                        .padding(.horizontal, LayoutTokens.paddingM)
                        .padding(.vertical, 8)
                        .background(ColorTokens.electricCyan.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, LayoutTokens.spacingS)
            }
        }
        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
    }
}

#Preview {
    FriendsView()
        .preferredColorScheme(.dark)
}
