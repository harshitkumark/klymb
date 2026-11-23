//
//  HealthKitServiceProtocol.swift
//  klymb
//
//  Protocol for Apple HealthKit queries, observers, and background delivery.
//  (AGENTS.md Rule 16: Protocol DI, Rule 17: No health data leak, Rule 2 & 3: Server scoring).
//

import Foundation
import HealthKit

public enum HealthKitPermissionStatus: Equatable, Sendable {
    case notDetermined
    case sharingDenied
    case sharingAuthorized
    case unavailable
}

public struct HealthKitSampleResult: Equatable {
    public let activities: [Activity]
    public let deletedSampleIds: [String]
    public let newAnchor: HKQueryAnchor?

    public init(
        activities: [Activity],
        deletedSampleIds: [String] = [],
        newAnchor: HKQueryAnchor? = nil
    ) {
        self.activities = activities
        self.deletedSampleIds = deletedSampleIds
        self.newAnchor = newAnchor
    }
}

public protocol HealthKitServiceProtocol: AnyObject {
    /// Whether HealthKit is supported on the current hardware/OS
    var isHealthDataAvailable: Bool { get }

    /// Requests read authorization for the given habit types
    func requestAuthorization(habitKeys: [String]) async throws -> Bool

    /// Checks the current authorization status for a specific habit key
    func authorizationStatus(for habitKey: String) -> HealthKitPermissionStatus

    /// Incremental anchored query fetching only new/updated samples since the anchor
    func fetchNewSamples(
        for habitKey: String,
        habitId: Int64,
        anchor: HKQueryAnchor?,
        limit: Int
    ) async throws -> HealthKitSampleResult

    /// Enables background observer query to receive telemetry in the background
    func enableBackgroundDelivery(for habitKey: String) async throws

    /// Starts observing live changes for active habits
    func startObserving(
        for habitKeys: [String],
        onUpdate: @escaping (String) -> Void
    )

    /// Stops all active observer queries
    func stopObserving()
}
