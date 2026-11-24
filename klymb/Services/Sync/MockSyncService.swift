//
//  MockSyncService.swift
//  klymb
//
//  Mock Sync Service for SwiftUI previews, simulator testing, and unit tests.
//  (AGENTS.md Rule 16: Protocol DI).
//

import Foundation

public final class MockSyncService: SyncServiceProtocol {
    public var syncStatus: SyncStatus = .idle
    public var lastSyncedAt: Date? = Date().addingTimeInterval(-1800) // 30 min ago
    public var pendingCount: Int = 0
    public var simulatedSummary: SyncSummary = SyncSummary(accepted: 5, duplicate: 0, rejected: 0)
    public var shouldThrowError: Bool = false

    public init(pendingCount: Int = 0) {
        self.pendingCount = pendingCount
    }

    public func enqueue(activities: [Activity]) async throws {
        if shouldThrowError {
            throw NSError(domain: "com.klymb.sync.mock", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to enqueue mock activities"])
        }
        pendingCount += activities.count
    }

    public func syncAllHabits() async throws -> SyncSummary {
        if shouldThrowError {
            syncStatus = .error(message: "Simulated sync failure")
            throw NSError(domain: "com.klymb.sync.mock", code: -2, userInfo: [NSLocalizedDescriptionKey: "Simulated sync failure"])
        }

        syncStatus = .syncing(progress: 0.5)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s simulated delay

        let completedDate = Date()
        self.lastSyncedAt = completedDate
        self.pendingCount = 0
        self.syncStatus = .success(lastSyncedAt: completedDate, summary: simulatedSummary)
        return simulatedSummary
    }

    public func flushPendingQueue() async throws -> SyncSummary {
        if shouldThrowError {
            syncStatus = .error(message: "Failed to flush queue")
            throw NSError(domain: "com.klymb.sync.mock", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to flush queue"])
        }

        let completedDate = Date()
        self.lastSyncedAt = completedDate
        self.pendingCount = 0
        self.syncStatus = .success(lastSyncedAt: completedDate, summary: simulatedSummary)
        return simulatedSummary
    }

    public func startBackgroundObservers() async {}
}
