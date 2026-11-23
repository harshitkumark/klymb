//
//  FriendsViewModel.swift
//  klymb
//
//  ViewModel for Friends, Athlete Search, and Social Interactions (PRD §F11 & Backend B11).
//  Follows AGENTS.md Rules 2, 15, 16.
//

import SwiftUI
import Combine

public enum FriendsTab: String, CaseIterable, Identifiable {
    case friends = "My Friends"
    case requests = "Requests"
    case search = "Discover"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .friends: return "person.2.fill"
        case .requests: return "person.badge.plus"
        case .search: return "magnifyingglass"
        }
    }
}

@MainActor
public final class FriendsViewModel: ObservableObject {
    @Published public var selectedTab: FriendsTab = .friends
    @Published public var searchQuery: String = ""
    @Published public var friends: [FriendItem] = []
    @Published public var incomingRequests: [FriendItem] = []
    @Published public var searchResults: [FriendItem] = []
    @Published public var selectedFriend: FriendItem? = nil
    @Published public var cheeredUserIds: Set<UUID> = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil

    private let socialService: SocialServiceProtocol
    private var searchCancellable: AnyCancellable?

    public init(socialService: SocialServiceProtocol) {
        self.socialService = socialService
        setupSearchDebounce()
    }

    public init(container: AppContainerProtocol = AppContainer.mock) {
        self.socialService = container.socialService
        setupSearchDebounce()
    }

    private func setupSearchDebounce() {
        searchCancellable = $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task {
                    await self?.performSearch(query: query)
                }
            }
    }

    // MARK: - Actions

    public func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            async let fetchedFriends = socialService.getFriends()
            async let fetchedRequests = socialService.getIncomingRequests()

            let (f, r) = try await (fetchedFriends, fetchedRequests)
            self.friends = f
            self.incomingRequests = r
            self.isLoading = false
        } catch {
            self.errorMessage = "Unable to load friends. Pull down to refresh."
            self.isLoading = false
        }
    }

    public func performSearch(query: String) async {
        do {
            self.searchResults = try await socialService.searchUsers(query: query)
        } catch {
            self.searchResults = []
        }
    }

    public func sendRequest(to user: FriendItem) async {
        do {
            try await socialService.sendFriendRequest(targetUserId: user.id)
            HapticManager.selection()
            if let idx = searchResults.firstIndex(where: { $0.id == user.id }) {
                searchResults[idx].status = .pendingSent
            }
        } catch {
            HapticManager.error()
        }
    }

    public func acceptRequest(from user: FriendItem) async {
        do {
            try await socialService.acceptFriendRequest(requesterId: user.id)
            HapticManager.celebration()
            incomingRequests.removeAll { $0.id == user.id }
            var accepted = user
            accepted.status = .friends
            friends.append(accepted)
        } catch {
            HapticManager.error()
        }
    }

    public func declineRequest(from user: FriendItem) async {
        do {
            try await socialService.declineFriendRequest(requesterId: user.id)
            HapticManager.buttonTap()
            incomingRequests.removeAll { $0.id == user.id }
        } catch {
            HapticManager.error()
        }
    }

    public func cheer(user: FriendItem) async {
        guard !cheeredUserIds.contains(user.id) else { return }
        cheeredUserIds.insert(user.id)
        HapticManager.celebration()

        do {
            try await socialService.cheerFriend(targetUserId: user.id)
        } catch {
            // Non-critical action
        }
    }

    public func selectFriend(_ friend: FriendItem) {
        selectedFriend = friend
        HapticManager.selection()
    }

    public func dismissFriendDetail() {
        selectedFriend = nil
    }
}
