//
//  ManualLogViewModel.swift
//  klymb
//
//  ViewModel coordinating manual activity logging with estimated KP preview (PRD §F6).
//  (AGENTS.md Rule 2 & 3: Server scoring, Rule 15: SwiftUI + MVVM, Rule 17: Local queue).
//

import SwiftUI
import Combine

@MainActor
public final class ManualLogViewModel: ObservableObject {
    @Published public var selectedType: ManualLogType = .hydration {
        didSet {
            resetDefaultQuantity()
        }
    }
    @Published public var quantity: Double = 500
    @Published public var selectedWorkoutType: WorkoutTypeOption = WorkoutTypeOption.allOptions[0]
    @Published public var isSubmitting: Bool = false
    @Published public var showSuccessToast: Bool = false
    @Published public var successMessage: String = ""
    @Published public var errorMessage: String? = nil

    private let syncService: SyncServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol

    public init(container: AppContainerProtocol = AppContainer.mock) {
        self.syncService = container.syncService
        self.analyticsService = container.analyticsService
    }

    public var estimatedKP: Int {
        selectedType.estimateKP(for: quantity)
    }

    public func selectType(_ type: ManualLogType) {
        HapticManager.shared.selection()
        self.selectedType = type
    }

    public func selectPreset(_ preset: Double) {
        HapticManager.shared.buttonTap()
        self.quantity = preset
    }

    public func increment() {
        HapticManager.shared.buttonTap()
        quantity = min(selectedType.maxManualValue, quantity + selectedType.stepAmount)
    }

    public func decrement() {
        HapticManager.shared.buttonTap()
        quantity = max(selectedType.stepAmount, quantity - selectedType.stepAmount)
    }

    public func submitActivity() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        defer { isSubmitting = false }

        let now = Date()
        let startedAt: Date
        if selectedType == .hydration {
            startedAt = now
        } else {
            // Started 'quantity' minutes ago
            startedAt = now.addingTimeInterval(-quantity * 60)
        }

        var deviceInfo: [String: String] = [
            "log_type": "manual_entry"
        ]
        if selectedType == .workout {
            deviceInfo["workout_subtype"] = selectedWorkoutType.name
        }

        let activity = Activity(
            habitId: selectedType.habitId,
            habitKey: selectedType.rawValue,
            quantity: quantity,
            unit: selectedType.unit,
            startedAt: startedAt,
            endedAt: now,
            source: "manual",
            sourceSampleId: "manual_\(UUID().uuidString)",
            wasUserEntered: true,
            kpEarned: nil,
            deviceInfo: deviceInfo
        )

        do {
            // 1. Enqueue in persistent offline queue
            try await syncService.enqueue(activities: [activity])

            // 2. Flush queue to backend
            _ = try await syncService.flushPendingQueue()

            // 3. Track privacy-preserving analytics (category only, zero biometrics)
            analyticsService.track(event: .manualLogSubmitted(category: selectedType.rawValue))

            HapticManager.shared.celebration()

            let formattedQty = Int(quantity)
            self.successMessage = "Logged \(formattedQty) \(selectedType.unit) • ~\(estimatedKP) KP estimated"
            self.showSuccessToast = true

            // Reset after success
            resetDefaultQuantity()
        } catch {
            self.errorMessage = "Failed to sync: \(error.localizedDescription)"
            HapticManager.shared.error()
        }
    }

    private func resetDefaultQuantity() {
        switch selectedType {
        case .hydration:
            quantity = 500
        case .workout:
            quantity = 30
        case .mindfulness:
            quantity = 15
        }
    }
}
