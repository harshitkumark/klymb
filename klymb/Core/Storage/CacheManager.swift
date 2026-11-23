//
//  CacheManager.swift
//  klymb
//
//  Local disk and memory cache fallback for offline resiliency (PRD §F16).
//  Follows AGENTS.md Rules 14, 15, 16.
//

import Foundation

public final class CacheManager: @unchecked Sendable {
    public static let shared = CacheManager()

    private let userDefaults: UserDefaults
    private let queue = DispatchQueue(label: "klymb.cache.queue", attributes: .concurrent)

    private struct CachedItem<T: Codable>: Codable {
        let value: T
        let expirationDate: Date?

        var isExpired: Bool {
            guard let expirationDate = expirationDate else { return false }
            return Date() > expirationDate
        }
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Save

    public func set<T: Codable>(
        _ value: T,
        forKey key: String,
        ttl: TimeInterval? = nil
    ) {
        let expiration = ttl.map { Date().addingTimeInterval($0) }
        let item = CachedItem(value: value, expirationDate: expiration)

        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            do {
                let data = try JSONEncoder().encode(item)
                self.userDefaults.set(data, forKey: key)
            } catch {
                #if DEBUG
                print("[CacheManager] Failed to encode value for key \(key): \(error)")
                #endif
            }
        }
    }

    // MARK: - Retrieve

    public func get<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        queue.sync {
            guard let data = userDefaults.data(forKey: key) else { return nil }
            do {
                let item = try JSONDecoder().decode(CachedItem<T>.self, from: data)
                if item.isExpired {
                    userDefaults.removeObject(forKey: key)
                    return nil
                }
                return item.value
            } catch {
                #if DEBUG
                print("[CacheManager] Failed to decode value for key \(key): \(error)")
                #endif
                return nil
            }
        }
    }

    // MARK: - Eviction

    public func remove(forKey key: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.userDefaults.removeObject(forKey: key)
        }
    }

    public func clearAll(prefix: String = "klymb.cache.") {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            let allKeys = self.userDefaults.dictionaryRepresentation().keys
            for key in allKeys where key.hasPrefix(prefix) {
                self.userDefaults.removeObject(forKey: key)
            }
        }
    }
}

// MARK: - Well-Known Cache Keys
public enum CacheKeys {
    public static let leaderboards = "klymb.cache.leaderboards"
    public static let habits = "klymb.cache.habits"
    public static let streak = "klymb.cache.streak"
    public static let profile = "klymb.cache.profile"
    public static let challenges = "klymb.cache.challenges"
}
