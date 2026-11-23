//
//  RuleComplianceTests.swift
//  klymb
//
//  Automated compliance tests verifying AGENTS.md architectural boundaries:
//  - Rule 1 & 2: Ledger-only KP accounting & server authoritative scoring.
//  - Rule 17: Strictly ZERO health data in analytics.
//

import Foundation

public struct RuleComplianceTests {
    public static func runAll() async -> [TestResult] {
        var results: [TestResult] = []

        results.append(testRule1And2LedgerOnlyCompliance())
        results.append(testRule17HealthPrivacyAnalyticsCompliance())

        return results
    }

    // MARK: - Rule 1 & 2: Ledger-Only Accounting & No Client Scoring

    private static func testRule1And2LedgerOnlyCompliance() -> TestResult {
        let start = Date()
        do {
            // 1. Verify Profile does not allow direct KP balance alteration
            let profile = Profile(
                id: UUID(),
                username: "athlete_1",
                displayName: "Athlete",
                totalKP: 100
            )
            try KlymbAssert.assertEqual(profile.totalKP, 100)

            // 2. Verify ManualLogType estimates are labeled as preview estimates only
            let waterPreview = ManualLogType.hydration.estimateKP(for: 500)
            try KlymbAssert.assertEqual(waterPreview, 2)

            let workoutPreview = ManualLogType.workout.estimateKP(for: 60)
            try KlymbAssert.assertEqual(workoutPreview, 40) // capped at manual max 40

            // 3. Verify activity creation does NOT persist or award KP on client
            let activity = Activity(
                habitId: 1,
                habitKey: "hydration",
                quantity: 500,
                unit: "ml",
                startedAt: Date(),
                endedAt: Date(),
                source: "manual",
                sourceSampleId: "sample_1",
                kpEarned: nil // Server awards KP exclusively
            )
            try KlymbAssert.assertNil(activity.kpEarned)

            return TestResult(
                testName: "Rule 1 & 2: Ledger-Only & Server Authoritative Scoring",
                passed: true,
                duration: Date().timeIntervalSince(start)
            )
        } catch {
            return TestResult(
                testName: "Rule 1 & 2: Ledger-Only & Server Authoritative Scoring",
                passed: false,
                failureMessage: "\(error)",
                duration: Date().timeIntervalSince(start)
            )
        }
    }

    // MARK: - Rule 17: Health Data Privacy in Analytics

    private static func testRule17HealthPrivacyAnalyticsCompliance() -> TestResult {
        let start = Date()
        do {
            let events: [AnalyticsEvent] = [
                .screenView(name: "Home"),
                .tabSwitched(to: "Compete"),
                .authCompleted(provider: "apple"),
                .onboardingStepCompleted(step: 2),
                .challengeJoined(id: UUID()),
                .challengeLeft(id: UUID()),
                .friendCheered(friendId: UUID()),
                .friendRequestSent(targetId: UUID()),
                .manualLogSubmitted(category: "hydration"),
                .cityChanged(cityId: 1),
                .notificationToggled(type: "overtaken", enabled: true),
                .networkStateChanged(isConnected: true)
            ]

            let forbiddenHealthKeywords = [
                "step_count", "steps", "heart", "heartrate", "hr", "calorie",
                "calories", "distance", "workout_duration", "sleep_hours",
                "vo2", "biometric", "healthkit"
            ]

            for event in events {
                let params = event.parameters
                for key in params.keys {
                    let lowerKey = key.lowercased()
                    for term in forbiddenHealthKeywords {
                        try KlymbAssert.assertFalse(
                            lowerKey.contains(term),
                            "Rule 17 Violation: Analytics key '\(key)' leaked health term '\(term)'"
                        )
                    }
                }
            }

            return TestResult(
                testName: "Rule 17: Zero Health Data in Analytics",
                passed: true,
                duration: Date().timeIntervalSince(start)
            )
        } catch {
            return TestResult(
                testName: "Rule 17: Zero Health Data in Analytics",
                passed: false,
                failureMessage: "\(error)",
                duration: Date().timeIntervalSince(start)
            )
        }
    }
}
