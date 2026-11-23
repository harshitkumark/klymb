//
//  HealthKitService.swift
//  klymb
//
//  Production implementation of Apple HealthKit integration (PRD §F5 & Architecture §4).
//  Enforces AGENTS.md Rule 17 (no health data leak) and Rule 2 & 3 (no client scoring).
//

import Foundation
import HealthKit

public final class HealthKitService: HealthKitServiceProtocol {
    private let healthStore: HKHealthStore?
    private var activeObserverQueries: [String: HKObserverQuery] = [:]
    private let queryQueue = DispatchQueue(label: "com.klymb.healthkit.queryQueue", qos: .utility)

    public init(healthStore: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil) {
        self.healthStore = healthStore
    }

    public var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable() && healthStore != nil
    }

    // MARK: - Authorization
    public func requestAuthorization(habitKeys: [String]) async throws -> Bool {
        guard let store = healthStore else {
            return false
        }

        var typesToRead = Set<HKObjectType>()
        for key in habitKeys {
            if let type = objectType(for: key) {
                typesToRead.insert(type)
            }
        }

        guard !typesToRead.isEmpty else {
            return true
        }

        return try await withCheckedThrowingContinuation { continuation in
            store.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }

    public func authorizationStatus(for habitKey: String) -> HealthKitPermissionStatus {
        guard let store = healthStore, let type = objectType(for: habitKey) else {
            return .unavailable
        }

        switch store.authorizationStatus(for: type) {
        case .notDetermined:
            return .notDetermined
        case .sharingDenied:
            return .sharingDenied
        case .sharingAuthorized:
            return .sharingAuthorized
        @unknown default:
            return .notDetermined
        }
    }

    // MARK: - Anchored Object Query
    public func fetchNewSamples(
        for habitKey: String,
        habitId: Int64,
        anchor: HKQueryAnchor?,
        limit: Int = 500
    ) async throws -> HealthKitSampleResult {
        guard let store = healthStore, let sampleType = sampleType(for: habitKey) else {
            return HealthKitSampleResult(activities: [])
        }

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: sampleType,
                predicate: nil,
                anchor: anchor,
                limit: limit
            ) { [weak self] _, samples, deletedObjects, newAnchor, error in
                guard let self = self else {
                    continuation.resume(returning: HealthKitSampleResult(activities: []))
                    return
                }

                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                var activities: [Activity] = []
                let rawSamples = samples ?? []

                for sample in rawSamples {
                    if let activity = self.mapSampleToActivity(sample, habitKey: habitKey, habitId: habitId) {
                        activities.append(activity)
                    }
                }

                let deletedIds = deletedObjects?.map { $0.uuid.uuidString } ?? []
                continuation.resume(returning: HealthKitSampleResult(
                    activities: activities,
                    deletedSampleIds: deletedIds,
                    newAnchor: newAnchor
                ))
            }

            store.execute(query)
        }
    }

    // MARK: - Background Delivery & Observers
    public func enableBackgroundDelivery(for habitKey: String) async throws {
        guard let store = healthStore, let sampleType = sampleType(for: habitKey) else {
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.enableBackgroundDelivery(for: sampleType, frequency: .hourly) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    public func startObserving(
        for habitKeys: [String],
        onUpdate: @escaping (String) -> Void
    ) {
        guard let store = healthStore else { return }

        for key in habitKeys {
            guard let sampleType = sampleType(for: key) else { continue }
            // Avoid duplicate observer query for same key
            if activeObserverQueries[key] != nil { continue }

            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
                defer { completionHandler() }
                guard error == nil else { return }
                self?.queryQueue.async {
                    onUpdate(key)
                }
            }

            activeObserverQueries[key] = query
            store.execute(query)
        }
    }

    public func stopObserving() {
        guard let store = healthStore else { return }
        for (_, query) in activeObserverQueries {
            store.stop(query)
        }
        activeObserverQueries.removeAll()
    }

    // MARK: - Sample Mapping & Anti-Cheat Metadata (AGENTS.md Rule 17)
    private func mapSampleToActivity(
        _ sample: HKSample,
        habitKey: String,
        habitId: Int64
    ) -> Activity? {
        let sampleId = sample.uuid.uuidString
        let wasUserEntered = (sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool) ?? false

        var deviceInfo: [String: String] = [:]
        deviceInfo["source_bundle_id"] = sample.sourceRevision.source.bundleIdentifier
        if let device = sample.device {
            deviceInfo["device_name"] = device.name ?? "Apple Device"
            deviceInfo["device_model"] = device.model ?? "iOS Device"
        }

        let startedAt = sample.startDate
        let endedAt = sample.endDate

        var quantity: Double = 0.0
        var unit: String = ""

        switch habitKey {
        case "steps":
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            quantity = quantitySample.quantity.doubleValue(for: .count())
            unit = "count"

        case "running":
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            quantity = quantitySample.quantity.doubleValue(for: .meterUnit(with: .kilo))
            unit = "km"

        case "walking_distance":
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            quantity = quantitySample.quantity.doubleValue(for: .meterUnit(with: .kilo))
            unit = "km"

        case "workout":
            guard let workout = sample as? HKWorkout else { return nil }
            quantity = workout.duration / 60.0 // minutes
            unit = "minutes"

        case "hydration":
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            quantity = quantitySample.quantity.doubleValue(for: .literUnit(with: .milli))
            unit = "ml"

        case "sleep":
            guard let categorySample = sample as? HKCategorySample else { return nil }
            // Only count actual sleep states (core, deep, rem, or legacy asleep)
            if #available(iOS 16.0, *) {
                let validSleep = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                guard validSleep.contains(categorySample.value) else { return nil }
            } else {
                guard categorySample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue else { return nil }
            }
            quantity = endedAt.timeIntervalSince(startedAt) / 3600.0 // hours
            unit = "hours"

        case "mindfulness":
            guard sample is HKCategorySample else { return nil }
            quantity = endedAt.timeIntervalSince(startedAt) / 60.0 // minutes
            unit = "minutes"

        default:
            return nil
        }

        // Filter out zero or negative invalid quantities
        guard quantity > 0 else { return nil }

        return Activity(
            habitId: habitId,
            habitKey: habitKey,
            quantity: quantity,
            unit: unit,
            startedAt: startedAt,
            endedAt: endedAt,
            source: "healthkit",
            sourceSampleId: sampleId,
            wasUserEntered: wasUserEntered,
            kpEarned: nil,
            deviceInfo: deviceInfo
        )
    }

    // MARK: - HealthKit Type Resolvers
    private func objectType(for habitKey: String) -> HKObjectType? {
        sampleType(for: habitKey)
    }

    private func sampleType(for habitKey: String) -> HKSampleType? {
        switch habitKey {
        case "steps":
            return HKQuantityType.quantityType(forIdentifier: .stepCount)
        case "running", "walking_distance":
            return HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)
        case "workout":
            return HKWorkoutType.workoutType()
        case "hydration":
            return HKQuantityType.quantityType(forIdentifier: .dietaryWater)
        case "sleep":
            return HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
        case "mindfulness":
            return HKCategoryType.categoryType(forIdentifier: .mindfulSession)
        default:
            return nil
        }
    }
}
