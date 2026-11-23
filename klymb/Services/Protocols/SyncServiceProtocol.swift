//
//  SyncServiceProtocol.swift
//  klymb
//
//  Protocol for local activity queueing and reliable batch synchronization.
//  (AGENTS.md Rule 16: Protocol DI, Rule 17: No health data leak, PRD §F7).
//

import Foundation
import Combine

public enum SyncStatus: Equatable {
    case idle
    case syncing(progress: Double?)
    case success(lastSyncedAt: Date, summary: SyncSummary)
    case error(message: String)
}

public struct SyncSummary: Equatable {
    public let accepted: Int
    public let duplicate: Int
    public let rejected: Int

    public init(accepted: Int = 0, duplicate: Int = 0, rejected: Int = 0) {
        self.accepted = accepted
        self.duplicate = duplicate
        self.rejected = rejected
    }

    public var totalProcessed: Int {
        accepted + duplicate + rejected
    }
}

public struct SyncQueueItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let activity: Activity
    public var retryCount: Int
    public var lastAttemptAt: Date?
    public var lastErrorMessage: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        activity: Activity,
        retryCount: Int = 0,
        lastAttemptAt: Date? = nil,
        lastErrorMessage: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.activity = activity
        self.retryCount = retryCount
        self.lastAttemptAt = lastAttemptAt
        self.lastErrorMessage = lastErrorMessage
        self.createdAt = createdAt
    }
}

public protocol SyncServiceProtocol: AnyObject {
    /// Live sync status exposed to ViewModels & UI
    var syncStatus: SyncStatus { get }

    /// Timestamp of the last successful sync
    var lastSyncedAt: Date? { get }

    /// Current number of activities waiting in the offline/pending queue
    var pendingCount: Int { get }

    /// Enqueues activities (e.g. manual logs or single samples) into the local queue
    func enqueue(activities: [Activity]) async throws

    /// Queries HealthKit delta anchors for active habits, enqueues samples, and submits batch
    func syncAllHabits() async throws -> SyncSummary

    /// Flushes any pending items in the local queue to the backend RPC
    func flushPendingQueue() async throws -> SyncSummary
}
