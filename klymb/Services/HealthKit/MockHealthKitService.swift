//
//  MockHealthKitService.swift
//  klymb
//
//  Mock HealthKit service for Xcode previews, simulator testing, and automated tests.
//  (AGENTS.md Rule 16: Protocol DI, Rule 17: No health data leak).
//

import Foundation
import HealthKit

public final class MockHealthKitService: HealthKitServiceProtocol {
    public var isHealthDataAvailable: Bool = true
    public var simulatedPermissionStatus: HealthKitPermissionStatus = .sharingAuthorized
    public var shouldThrowError: Bool = false
    public var mockActivities: [String: [Activity]] = [:]

    private var observerCallbacks: [String: [(String) -> Void]] = [:]

    public init(populateDefaults: Bool = true) {
        if populateDefaults {
            populateDefaultActivities()
        }
    }

    public func requestAuthorization(habitKeys: [String]) async throws -> Bool {
        if shouldThrowError {
            throw NSError(domain: "com.klymb.healthkit.mock", code: -1, userInfo: [NSLocalizedDescriptionKey: "Simulated authorization failure"])
        }
        return simulatedPermissionStatus == .sharingAuthorized
    }

    public func authorizationStatus(for habitKey: String) -> HealthKitPermissionStatus {
        simulatedPermissionStatus
    }

    public func fetchNewSamples(
        for habitKey: String,
        habitId: Int64,
        anchor: HKQueryAnchor?,
        limit: Int = 500
    ) async throws -> HealthKitSampleResult {
        if shouldThrowError {
            throw NSError(domain: "com.klymb.healthkit.mock", code: -2, userInfo: [NSLocalizedDescriptionKey: "Simulated query failure"])
        }

        // Return activities for this habit
        let activities = mockActivities[habitKey] ?? []
        return HealthKitSampleResult(
            activities: Array(activities.prefix(limit)),
            deletedSampleIds: [],
            newAnchor: nil
        )
    }

    public func enableBackgroundDelivery(for habitKey: String) async throws {
        if shouldThrowError {
            throw NSError(domain: "com.klymb.healthkit.mock", code: -3, userInfo: [NSLocalizedDescriptionKey: "Simulated background delivery error"])
        }
    }

    public func startObserving(
        for habitKeys: [String],
        onUpdate: @escaping (String) -> Void
    ) {
        for key in habitKeys {
            if observerCallbacks[key] == nil {
                observerCallbacks[key] = []
            }
            observerCallbacks[key]?.append(onUpdate)
        }
    }

    public func stopObserving() {
        observerCallbacks.removeAll()
    }

    /// Helper to simulate incoming background HealthKit delivery
    public func triggerObserverUpdate(for habitKey: String) {
        if let callbacks = observerCallbacks[habitKey] {
            for callback in callbacks {
                callback(habitKey)
            }
        }
    }

    private func populateDefaultActivities() {
        let now = Date()
        let twoHoursAgo = now.addingTimeInterval(-7200)
        let oneHourAgo = now.addingTimeInterval(-3600)

        mockActivities["steps"] = [
            Activity(
                habitId: 1,
                habitKey: "steps",
                quantity: 7450,
                unit: "count",
                startedAt: twoHoursAgo,
                endedAt: now,
                source: "healthkit",
                sourceSampleId: UUID().uuidString,
                wasUserEntered: false,
                deviceInfo: [
                    "device_name": "Apple Watch",
                    "device_model": "Watch8,1",
                    "source_bundle_id": "com.apple.health"
                ]
            )
        ]

        mockActivities["running"] = [
            Activity(
                habitId: 2,
                habitKey: "running",
                quantity: 4.8,
                unit: "km",
                startedAt: twoHoursAgo,
                endedAt: oneHourAgo,
                source: "healthkit",
                sourceSampleId: UUID().uuidString,
                wasUserEntered: false,
                deviceInfo: [
                    "device_name": "Apple Watch",
                    "device_model": "Watch8,1",
                    "source_bundle_id": "com.apple.Fitness"
                ]
            )
        ]

        mockActivities["workout"] = [
            Activity(
                habitId: 4,
                habitKey: "workout",
                quantity: 45,
                unit: "minutes",
                startedAt: twoHoursAgo,
                endedAt: oneHourAgo,
                source: "healthkit",
                sourceSampleId: UUID().uuidString,
                wasUserEntered: false,
                deviceInfo: [
                    "device_name": "Apple Watch",
                    "device_model": "Watch8,1",
                    "source_bundle_id": "com.apple.Fitness"
                ]
            )
        ]

        mockActivities["hydration"] = [
            Activity(
                habitId: 5,
                habitKey: "hydration",
                quantity: 1250,
                unit: "ml",
                startedAt: oneHourAgo,
                endedAt: now,
                source: "healthkit",
                sourceSampleId: UUID().uuidString,
                wasUserEntered: true,
                deviceInfo: [
                    "device_name": "iPhone",
                    "device_model": "iPhone16,1",
                    "source_bundle_id": "com.apple.health"
                ]
            )
        ]

        mockActivities["sleep"] = [
            Activity(
                habitId: 6,
                habitKey: "sleep",
                quantity: 7.2,
                unit: "hours",
                startedAt: now.addingTimeInterval(-28800),
                endedAt: now.addingTimeInterval(-2880),
                source: "healthkit",
                sourceSampleId: UUID().uuidString,
                wasUserEntered: false,
                deviceInfo: [
                    "device_name": "Apple Watch",
                    "device_model": "Watch8,1",
                    "source_bundle_id": "com.apple.health"
                ]
            )
        ]
    }
}
