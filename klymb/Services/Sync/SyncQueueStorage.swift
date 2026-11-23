//
//  SyncQueueStorage.swift
//  klymb
//
//  Persistent local FIFO queue for activity samples before batch submission.
//  Guarantees offline resilience, idempotency, and retry tracking (PRD §F7).
//

import Foundation

public actor SyncQueueStorage {
    private var items: [SyncQueueItem] = []
    private let fileURL: URL
    private let maxRetries: Int = 10

    public init(fileName: String = "klymb_sync_queue.json") {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]

        let dir = appSupport.appendingPathComponent("Klymb", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        self.fileURL = dir.appendingPathComponent(fileName)
        loadFromDisk()
    }

    public var count: Int {
        items.count
    }

    public var allItems: [SyncQueueItem] {
        items
    }

    // MARK: - Enqueue
    public func enqueue(_ activities: [Activity]) {
        let existingSampleIds = Set(items.compactMap { $0.activity.sourceSampleId })

        var added = false
        for activity in activities {
            // Deduplicate if already present in local queue
            if let sampleId = activity.sourceSampleId, existingSampleIds.contains(sampleId) {
                continue
            }

            let queueItem = SyncQueueItem(activity: activity)
            items.append(queueItem)
            added = true
        }

        if added {
            saveToDisk()
        }
    }

    // MARK: - Batch Fetching
    public func peek(limit: Int = 500) -> [SyncQueueItem] {
        // Return oldest pending items that haven't exceeded retry limit
        let eligible = items.filter { $0.retryCount < maxRetries }
        return Array(eligible.prefix(limit))
    }

    // MARK: - Acknowledgement & Removal
    public func remove(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        items.removeAll { ids.contains($0.id) }
        saveToDisk()
    }

    public func removeBySampleIds(_ sampleIds: Set<String>) {
        guard !sampleIds.isEmpty else { return }
        items.removeAll { item in
            if let id = item.activity.sourceSampleId {
                return sampleIds.contains(id)
            }
            return false
        }
        saveToDisk()
    }

    // MARK: - Retry Handling
    public func recordRetry(for id: UUID, errorMessage: String) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].retryCount += 1
            items[index].lastAttemptAt = Date()
            items[index].lastErrorMessage = errorMessage
            saveToDisk()
        }
    }

    public func clear() {
        items.removeAll()
        saveToDisk()
    }

    // MARK: - Persistence
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Note: Never log raw activity health data (Rule 17)
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            self.items = try JSONDecoder().decode([SyncQueueItem].self, from: data)
        } catch {
            self.items = []
        }
    }
}
