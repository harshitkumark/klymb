//
//  ActivitySyncService.swift
//  klymb
//
//  Coordinates HealthKit incremental sync, local queue persistence,
//  and batch submission to Supabase backend (PRD §F7).
//  (AGENTS.md Rule 17: No health data leak, Rule 2 & 3: Server-side scoring).
//

import Foundation
import HealthKit
import Combine

@MainActor
public final class ActivitySyncService: ObservableObject, SyncServiceProtocol {
    @Published public private(set) var syncStatus: SyncStatus = .idle
    @Published public private(set) var lastSyncedAt: Date?
    @Published public private(set) var pendingCount: Int = 0

    private let healthKitService: HealthKitServiceProtocol
    private let activityService: ActivityServiceProtocol
    private let profileService: ProfileServiceProtocol
    private let queueStorage: SyncQueueStorage
    private let userDefaults: UserDefaults

    private var isSyncInProgress = false

    public init(
        healthKitService: HealthKitServiceProtocol,
        activityService: ActivityServiceProtocol,
        profileService: ProfileServiceProtocol,
        queueStorage: SyncQueueStorage = SyncQueueStorage(),
        userDefaults: UserDefaults = .standard
    ) {
        self.healthKitService = healthKitService
        self.activityService = activityService
        self.profileService = profileService
        self.queueStorage = queueStorage
        self.userDefaults = userDefaults

        Task {
            await refreshPendingCount()
        }
    }

    // MARK: - Enqueue
    public func enqueue(activities: [Activity]) async throws {
        await queueStorage.enqueue(activities)
        await refreshPendingCount()
    }

    // MARK: - Full Sync
    public func syncAllHabits() async throws -> SyncSummary {
        guard !isSyncInProgress else {
            return SyncSummary()
        }
        isSyncInProgress = true
        syncStatus = .syncing(progress: 0.1)

        defer {
            isSyncInProgress = false
        }

        do {
            // 1. Fetch user's active disciplines
            let userHabits = try await profileService.getUserHabits()
            let totalHabits = max(1, userHabits.count)

            var collectedCount = 0

            // 2. Query each habit from HealthKit using anchored queries
            for (index, habit) in userHabits.enumerated() {
                let anchor = loadAnchor(for: habit.key)
                let result = try await healthKitService.fetchNewSamples(
                    for: habit.key,
                    habitId: habit.id,
                    anchor: anchor,
                    limit: 500
                )

                if !result.activities.isEmpty {
                    await queueStorage.enqueue(result.activities)
                    collectedCount += result.activities.count
                }

                if let newAnchor = result.newAnchor {
                    saveAnchor(newAnchor, for: habit.key)
                }

                let progress = 0.1 + (0.4 * Double(index + 1) / Double(totalHabits))
                syncStatus = .syncing(progress: progress)
            }

            await refreshPendingCount()

            // 3. Flush pending queue to server
            syncStatus = .syncing(progress: 0.6)
            let summary = try await flushPendingQueueInternal()

            let completedDate = Date()
            self.lastSyncedAt = completedDate
            self.syncStatus = .success(lastSyncedAt: completedDate, summary: summary)

            return summary
        } catch {
            let errorMsg = error.localizedDescription
            self.syncStatus = .error(message: errorMsg)
            throw error
        }
    }

    // MARK: - Flush Queue
    public func flushPendingQueue() async throws -> SyncSummary {
        guard !isSyncInProgress else {
            return SyncSummary()
        }
        isSyncInProgress = true
        syncStatus = .syncing(progress: nil)

        defer {
            isSyncInProgress = false
        }

        do {
            let summary = try await flushPendingQueueInternal()
            let completedDate = Date()
            self.lastSyncedAt = completedDate
            self.syncStatus = .success(lastSyncedAt: completedDate, summary: summary)
            return summary
        } catch {
            self.syncStatus = .error(message: error.localizedDescription)
            throw error
        }
    }

    private func flushPendingQueueInternal() async throws -> SyncSummary {
        var totalAccepted = 0
        var totalDuplicate = 0
        var totalRejected = 0

        // Process in batches of up to 500 (PRD limit)
        while true {
            let batch = await queueStorage.peek(limit: 500)
            if batch.isEmpty {
                break
            }

            let activities = batch.map { $0.activity }
            do {
                let result = try await activityService.submitActivities(activities)
                totalAccepted += result.accepted
                totalDuplicate += result.duplicate
                totalRejected += result.rejected

                // Successfully processed (accepted or duplicate) are safe to remove from queue
                let successfulIds = Set(batch.map { $0.id })
                await queueStorage.remove(ids: successfulIds)
            } catch {
                // Network or server error: record retry with backoff on these items
                let errString = error.localizedDescription
                for item in batch {
                    await queueStorage.recordRetry(for: item.id, errorMessage: errString)
                }
                await refreshPendingCount()
                throw error
            }

            await refreshPendingCount()
        }

        return SyncSummary(accepted: totalAccepted, duplicate: totalDuplicate, rejected: totalRejected)
    }

    // MARK: - HealthKit Background Observers
    public func startBackgroundObservers() async {
        do {
            let userHabits = try await profileService.getUserHabits()
            let keys = userHabits.map { $0.key }

            healthKitService.startObserving(for: keys) { [weak self] updatedKey in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    _ = try? await self.syncAllHabits()
                }
            }
        } catch {
            // Silently continue if habits not loaded yet
        }
    }

    // MARK: - Anchor Persistence
    private func loadAnchor(for habitKey: String) -> HKQueryAnchor? {
        guard let data = userDefaults.data(forKey: anchorKey(for: habitKey)) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private func saveAnchor(_ anchor: HKQueryAnchor, for habitKey: String) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            userDefaults.set(data, forKey: anchorKey(for: habitKey))
        }
    }

    private func anchorKey(for habitKey: String) -> String {
        "klymb_hk_anchor_\(habitKey)"
    }

    private func refreshPendingCount() async {
        self.pendingCount = await queueStorage.count
    }
}
