//
//  HapticManager.swift
//  klymb
//
//  Centralized haptic feedback controller matching docs/DESIGN_SYSTEM.md §7.
//  Respects UIAccessibility.isReduceMotionEnabled (Rule 18).
//

import UIKit

@MainActor
public final class HapticManager {
    public static let shared = HapticManager()

    private init() {}

    private var isHapticsAllowed: Bool {
        !UIAccessibility.isReduceMotionEnabled
    }

    /// Button tap: subtle light feedback
    public func buttonTap() {
        guard isHapticsAllowed else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Tab bar switch: selection tick
    public func tabSwitch() {
        guard isHapticsAllowed else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// KP earned: success notification
    public func kpEarned() {
        guard isHapticsAllowed else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Rank up celebration: heavy impact + success
    public func rankUp() {
        guard isHapticsAllowed else { return }
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.prepare()
        impact.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let notification = UINotificationFeedbackGenerator()
            notification.prepare()
            notification.notificationOccurred(.success)
        }
    }

    /// Rank down: warning
    public func rankDown() {
        guard isHapticsAllowed else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Achievement unlocked: heavy impact
    public func achievementUnlocked() {
        guard isHapticsAllowed else { return }
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.prepare()
        impact.impactOccurred()
    }

    /// Error or invalid input
    public func error() {
        guard isHapticsAllowed else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}
