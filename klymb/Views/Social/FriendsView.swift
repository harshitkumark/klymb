//
//  FriendsView.swift
//  klymb
//
//  Friends & Social modal: unified sliding switcher, athlete search,
//  incoming friend requests, and friend cheering inside grouped containers.
//

import SwiftUI

public struct FriendsView: View {
    @StateObject private var viewModel: FriendsViewModel
    @Environment(\.dismiss) private var dismiss

    public init(container: AppContainerProtocol = AppContainer.mock) {
        _viewModel = StateObject(wrappedValue: FriendsViewModel(container: container))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.KlymbBackground.primary.ignoresSafeArea()

                VStack(spacing: KlymbSpacing.md) {
                    // 1. Sliding Social Tabs Switcher
                    KlymbSegmentedControl(
                        options: FriendsTab.allCases,
                        selection: $viewModel.selectedTab,
                        title: { $0.rawValue },
                        badgeCount: { $0 == .requests ? viewModel.incomingRequests.count : 0 },
                        onSelect: { tab in
                            viewModel.selectedTab = tab
                            HapticManager.selection()
                        }
                    )
                    .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    .padding(.top, KlymbSpacing.sm)

                    // 2. Search Field on Discover tab
                    if viewModel.selectedTab == .search {
                        SearchBarView(text: $viewModel.searchQuery)
                            .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                    }

                    // 3. Tab Content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: KlymbSpacing.md) {
                            switch viewModel.selectedTab {
                            case .friends:
                                if viewModel.friends.isEmpty && !viewModel.isLoading {
                                    EmptyFriendsView(
                                        title: "No Friends Yet",
                                        subtitle: "Connect with athletes in your city to track progress and cheer each other on.",
                                        buttonTitle: "Find Athletes",
                                        action: { viewModel.selectedTab = .search }
                                    )
                                    .padding(.top, 48)
                                } else {
                                    KlymbGroupedSurface {
                                        ForEach(Array(viewModel.friends.enumerated()), id: \.element.id) { idx, friend in
                                            if idx > 0 {
                                                Divider().background(Color.KlymbBorder.subtle).padding(.leading, 64)
                                            }
                                            FriendRow(
                                                friend: friend,
                                                isCheered: viewModel.cheeredUserIds.contains(friend.id),
                                                onCheer: { Task { await viewModel.cheer(user: friend) } },
                                                onTap: { viewModel.selectFriend(friend) }
                                            )
                                        }
                                    }
                                }

                            case .requests:
                                if viewModel.incomingRequests.isEmpty && !viewModel.isLoading {
                                    EmptyFriendsView(
                                        title: "No Pending Requests",
                                        subtitle: "You're all caught up. New friend requests will appear here.",
                                        buttonTitle: "Discover Athletes",
                                        action: { viewModel.selectedTab = .search }
                                    )
                                    .padding(.top, 48)
                                } else {
                                    KlymbGroupedSurface {
                                        ForEach(Array(viewModel.incomingRequests.enumerated()), id: \.element.id) { idx, request in
                                            if idx > 0 {
                                                Divider().background(Color.KlymbBorder.subtle).padding(.leading, 64)
                                            }
                                            RequestRow(
                                                request: request,
                                                onAccept: { Task { await viewModel.acceptRequest(from: request) } },
                                                onDecline: { Task { await viewModel.declineRequest(from: request) } },
                                                onTap: { viewModel.selectFriend(request) }
                                            )
                                        }
                                    }
                                }

                            case .search:
                                if viewModel.searchResults.isEmpty && !viewModel.isLoading {
                                    EmptyFriendsView(
                                        title: "Find Your Squad",
                                        subtitle: "Search by username or display name to send friend requests.",
                                        buttonTitle: nil,
                                        action: nil
                                    )
                                    .padding(.top, 48)
                                } else {
                                    KlymbGroupedSurface {
                                        ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { idx, user in
                                            if idx > 0 {
                                                Divider().background(Color.KlymbBorder.subtle).padding(.leading, 64)
                                            }
                                            DiscoverUserRow(
                                                user: user,
                                                onAddFriend: { Task { await viewModel.sendRequest(to: user) } },
                                                onTap: { viewModel.selectFriend(user) }
                                            )
                                        }
                                    }
                                }
                            }

                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                        .padding(.top, KlymbSpacing.xs)
                        .padding(.bottom, KlymbSpacing.xl)
                    }
                    .refreshable {
                        await viewModel.loadData()
                    }
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.KlymbBackground.primary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(Color.KlymbAccent.soft)
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

// MARK: - Search Bar
private struct SearchBarView: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: KlymbSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.KlymbText.tertiary)

            TextField("Search by username or name...", text: $text)
                .font(Font.Klymb.bodySmall)
                .foregroundStyle(Color.KlymbText.primary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.KlymbText.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, KlymbSpacing.md)
        .frame(minHeight: 44)
        .background(Color.KlymbBackground.secondary)
        .clipShape(RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KlymbRadius.md, style: .continuous)
                .strokeBorder(Color.KlymbBorder.default, lineWidth: 1)
        )
    }
}

// MARK: - Grouped Rows
private struct FriendRow: View {
    let friend: FriendItem
    let isCheered: Bool
    let onCheer: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: KlymbSpacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.KlymbBackground.tertiary)
                        .frame(width: 40, height: 40)

                    Image(systemName: friend.avatarIconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(friend.rankTier.tierColor)
                }
                .overlay(
                    Circle().strokeBorder(friend.rankTier.tierColor.opacity(0.55), lineWidth: 1.25)
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(friend.titleDisplay)
                            .font(Font.Klymb.bodySmall.weight(.semibold))
                            .foregroundStyle(Color.KlymbText.primary)
                            .lineLimit(1)

                        if friend.streak > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 9))
                                Text("\(friend.streak)")
                                    .font(Font.Klymb.telemetry)
                            }
                            .foregroundStyle(Color.KlymbAccent.soft)
                        }
                    }

                    Text("\(friend.totalKP.formatted()) KP\(friend.cityName.map { " • \($0)" } ?? "")")
                        .font(Font.Klymb.captionSmall)
                        .foregroundStyle(Color.KlymbText.secondary)
                }

                Spacer()

                Button(action: onCheer) {
                    HStack(spacing: 4) {
                        Image(systemName: isCheered ? "flame.fill" : "hands.clap.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(isCheered ? "Cheered" : "Cheer")
                            .font(Font.Klymb.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isCheered ? Color.KlymbAccent.primaryMuted : Color.KlymbBackground.tertiary)
                    .foregroundStyle(isCheered ? Color.KlymbAccent.soft : Color.KlymbText.primary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, KlymbSpacing.lg)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(friend.titleDisplay), \(friend.totalKP) KP, streak of \(friend.streak) days")
    }
}

private struct RequestRow: View {
    let request: FriendItem
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: KlymbSpacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.KlymbBackground.tertiary)
                        .frame(width: 40, height: 40)

                    Image(systemName: request.avatarIconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(request.rankTier.tierColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(request.titleDisplay)
                        .font(Font.Klymb.bodySmall.weight(.semibold))
                        .foregroundStyle(Color.KlymbText.primary)

                    Text("\(request.totalKP.formatted()) KP • \(request.cityName ?? "Athlete")")
                        .font(Font.Klymb.captionSmall)
                        .foregroundStyle(Color.KlymbText.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: onDecline) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.KlymbText.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color.KlymbBackground.tertiary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Decline request")

                    Button(action: onAccept) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.KlymbText.inverse)
                            .frame(width: 32, height: 32)
                            .background(Color.KlymbAccent.boneCTA)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Accept request")
                }
            }
            .padding(.horizontal, KlymbSpacing.lg)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct DiscoverUserRow: View {
    let user: FriendItem
    let onAddFriend: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: KlymbSpacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.KlymbBackground.tertiary)
                        .frame(width: 40, height: 40)

                    Image(systemName: user.avatarIconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(user.rankTier.tierColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.titleDisplay)
                        .font(Font.Klymb.bodySmall.weight(.semibold))
                        .foregroundStyle(Color.KlymbText.primary)

                    Text("\(user.totalKP.formatted()) KP • \(user.cityName ?? "Global")")
                        .font(Font.Klymb.captionSmall)
                        .foregroundStyle(Color.KlymbText.secondary)
                }

                Spacer()

                if user.status == .friends {
                    Text("Friends")
                        .font(Font.Klymb.telemetry)
                        .foregroundStyle(Color.KlymbSemantic.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.KlymbSemantic.success.opacity(0.12))
                        .clipShape(Capsule())
                } else if user.status == .pendingSent {
                    Text("Sent")
                        .font(Font.Klymb.telemetry)
                        .foregroundStyle(Color.KlymbText.tertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.KlymbBackground.tertiary)
                        .clipShape(Capsule())
                } else {
                    Button(action: onAddFriend) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("Add")
                                .font(Font.Klymb.caption.weight(.bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.KlymbAccent.boneCTA)
                        .foregroundStyle(Color.KlymbText.inverse)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, KlymbSpacing.lg)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Friend Profile Modal
private struct FriendProfileModal: View {
    let friend: FriendItem
    let isCheered: Bool
    let onCheer: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: KlymbSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(Color.KlymbBackground.tertiary)
                        .frame(width: 84, height: 84)

                    Image(systemName: friend.avatarIconName)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(friend.rankTier.tierColor)
                }
                .overlay(
                    Circle()
                        .strokeBorder(friend.rankTier.tierColor.opacity(0.75), lineWidth: 2)
                )
                .padding(.top, KlymbSpacing.md)

                VStack(spacing: 4) {
                    Text(friend.titleDisplay)
                        .font(Font.Klymb.titleSmall)
                        .foregroundStyle(Color.KlymbText.primary)

                    Text("@\(friend.username)")
                        .font(Font.Klymb.bodySmall)
                        .foregroundStyle(Color.KlymbText.tertiary)

                    if let city = friend.cityName {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 12))
                            Text(city)
                        }
                        .font(Font.Klymb.caption)
                        .foregroundStyle(Color.KlymbAccent.soft)
                        .padding(.top, 2)
                    }
                }

                HStack(spacing: KlymbSpacing.md) {
                    StatTile(
                        icon: "bolt.fill",
                        value: "\(friend.totalKP.formatted())",
                        label: "Total KP",
                        valueColor: Color.KlymbAccent.soft
                    )

                    StatTile(
                        icon: "flame.fill",
                        value: "\(friend.streak)d",
                        label: "Streak",
                        valueColor: Color.KlymbAccent.primary
                    )

                    StatTile(
                        icon: friend.rankTier.iconName,
                        value: friend.rankTier.rawValue.components(separatedBy: " ").first ?? "Rank",
                        label: "Tier",
                        valueColor: friend.rankTier.tierColor
                    )
                }
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)

                Spacer()

                PrimaryButton(
                    isCheered ? "Cheered" : "Cheer Athlete",
                    icon: isCheered ? "flame.fill" : "hands.clap.fill",
                    tone: isCheered ? .terracotta : .bone,
                    action: onCheer
                )
                .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
                .padding(.bottom, KlymbSpacing.md)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.KlymbBackground.primary.ignoresSafeArea())
            .navigationTitle("Athlete Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onClose)
                        .foregroundStyle(Color.KlymbAccent.soft)
                }
            }
        }
    }
}

private struct EmptyFriendsView: View {
    let title: String
    let subtitle: String
    let buttonTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: KlymbSpacing.md) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.KlymbText.tertiary)

            Text(title)
                .font(Font.Klymb.headline)
                .foregroundStyle(Color.KlymbText.primary)

            Text(subtitle)
                .font(Font.Klymb.bodySmall)
                .foregroundStyle(Color.KlymbText.secondary)
                .multilineTextAlignment(.center)

            if let btn = buttonTitle, let act = action {
                Button(action: act) {
                    Text(btn)
                        .font(Font.Klymb.caption.weight(.semibold))
                        .foregroundStyle(Color.KlymbText.primary)
                        .padding(.horizontal, KlymbSpacing.lg)
                        .padding(.vertical, 9)
                        .klymbCardStyle(cornerRadius: KlymbRadius.full, isElevated: true)
                }
                .buttonStyle(KlymbPressableButtonStyle())
                .padding(.top, KlymbSpacing.xs)
            }
        }
        .padding(.horizontal, LayoutTokens.screenHorizontalPadding)
    }
}

#Preview {
    FriendsView()
        .preferredColorScheme(.dark)
}
