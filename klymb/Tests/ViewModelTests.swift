//
//  ViewModelTests.swift
//  klymb
//
//  Comprehensive unit tests covering ViewModels across all 5 tabs and settings:
//  Home, Log, Compete, Challenges, and Settings (PRD §F19).
//  Follows AGENTS.md Rules 15 & 16.
//

import Foundation

@MainActor
public struct ViewModelTests {
    public static func runAll() async -> [TestResult] {
        var results: [TestResult] = []

        results.append(await testHomeViewModel())
        results.append(await testManualLogViewModel())
        results.append(await testCompeteViewModel())
        results.append(await testChallengesViewModel())
        results.append(await testSettingsViewModel())

        return results
    }

    // MARK: - 1. HomeViewModel Tests

    public static func testHomeViewModel() async -> TestResult {
        let start = Date()
        do {
            let container = AppContainer.mock
            let vm = HomeViewModel(container: container)
            await vm.reloadData()

            // 1. Verify goal progress calculation
            try KlymbAssert.assertEqual(vm.dailyGoalKP, 300)
            try KlymbAssert.assertTrue(vm.goalProgressRatio >= 0.0 && vm.goalProgressRatio <= 2.0)

            // 2. Verify habit progresses populated
            try KlymbAssert.assertFalse(vm.habitProgresses.isEmpty, "Habit progresses should not be empty")

            // 3. Verify overtake nudge present
            try KlymbAssert.assertNotNil(vm.overtakeNudge, "Overtake nudge should be populated")
            try KlymbAssert.assertEqual(vm.overtakeNudge?.targetRivalUsername, "ravi")

            return TestResult(testName: "HomeViewModel Tests", passed: true, duration: Date().timeIntervalSince(start))
        } catch {
            return TestResult(testName: "HomeViewModel Tests", passed: false, failureMessage: "\(error)", duration: Date().timeIntervalSince(start))
        }
    }

    // MARK: - 2. ManualLogViewModel Tests

    public static func testManualLogViewModel() async -> TestResult {
        let start = Date()
        do {
            let container = AppContainer.mock
            let vm = ManualLogViewModel(container: container)

            // 1. Test Hydration defaults & estimation
            vm.selectType(.hydration)
            try KlymbAssert.assertEqual(vm.quantity, 500)
            try KlymbAssert.assertEqual(vm.estimatedKP, 2)

            // 2. Test Increment
            vm.increment()
            try KlymbAssert.assertEqual(vm.quantity, 550)

            // 3. Test Decrement
            vm.decrement()
            try KlymbAssert.assertEqual(vm.quantity, 500)

            // 4. Test Workout & Cap
            vm.selectType(.workout)
            vm.quantity = 60
            try KlymbAssert.assertEqual(vm.estimatedKP, 40) // capped at manual cap of 40

            // 5. Test Submission
            await vm.submitActivity()
            try KlymbAssert.assertTrue(vm.showSuccessToast)
            try KlymbAssert.assertNil(vm.errorMessage)

            return TestResult(testName: "ManualLogViewModel Tests", passed: true, duration: Date().timeIntervalSince(start))
        } catch {
            return TestResult(testName: "ManualLogViewModel Tests", passed: false, failureMessage: "\(error)", duration: Date().timeIntervalSince(start))
        }
    }

    // MARK: - 3. CompeteViewModel Tests

    public static func testCompeteViewModel() async -> TestResult {
        let start = Date()
        do {
            let container = AppContainer.mock
            let vm = CompeteViewModel(container: container)
            await vm.fetchLeaderboard()

            // 1. Verify entries loaded
            try KlymbAssert.assertFalse(vm.entries.isEmpty, "Leaderboard entries should be populated")

            // 2. Verify topThree contains ranks
            try KlymbAssert.assertTrue(vm.topThree.count <= 3)
            let ranks = Set(vm.topThree.map { $0.rank })
            try KlymbAssert.assertTrue(ranks.contains(1))

            // 3. Test scope filter changes
            vm.setScope(.global)
            try KlymbAssert.assertEqual(vm.selectedScope, .global)

            // 4. Test period filter changes
            vm.setPeriod(.allTime)
            try KlymbAssert.assertEqual(vm.selectedPeriod, .allTime)

            return TestResult(testName: "CompeteViewModel Tests", passed: true, duration: Date().timeIntervalSince(start))
        } catch {
            return TestResult(testName: "CompeteViewModel Tests", passed: false, failureMessage: "\(error)", duration: Date().timeIntervalSince(start))
        }
    }

    // MARK: - 4. ChallengesViewModel Tests

    public static func testChallengesViewModel() async -> TestResult {
        let start = Date()
        do {
            let container = AppContainer.mock
            let vm = ChallengesViewModel(container: container)
            await vm.fetchChallenges()

            // 1. Verify challenges loaded
            try KlymbAssert.assertFalse(vm.challenges.isEmpty, "Challenges list should not be empty")

            // 2. Test join action
            if let firstAvailable = vm.challenges.first(where: { !$0.isJoined }) {
                await vm.toggleJoin(for: firstAvailable)
                let updated = vm.challenges.first(where: { $0.id == firstAvailable.id })
                try KlymbAssert.assertTrue(updated?.isJoined == true)
            }

            // 3. Test category filter
            vm.setCategory(.daily)
            try KlymbAssert.assertEqual(vm.selectedCategory, .daily)
            for c in vm.filteredChallenges {
                try KlymbAssert.assertEqual(c.type, "daily")
            }

            return TestResult(testName: "ChallengesViewModel Tests", passed: true, duration: Date().timeIntervalSince(start))
        } catch {
            return TestResult(testName: "ChallengesViewModel Tests", passed: false, failureMessage: "\(error)", duration: Date().timeIntervalSince(start))
        }
    }

    // MARK: - 5. SettingsViewModel Tests

    public static func testSettingsViewModel() async -> TestResult {
        let start = Date()
        do {
            let container = AppContainer.mock
            let vm = SettingsViewModel(container: container)
            await vm.loadSettings()

            // 1. Test 30-day city cooldown calculation
            let recentChange = Date().addingTimeInterval(-5 * 86400) // 5 days ago
            let cooldownActive = CityChangeCooldown(lastChangedAt: recentChange)
            try KlymbAssert.assertFalse(cooldownActive.canChangeCity, "Cooldown should be active if changed 5 days ago")
            try KlymbAssert.assertTrue(cooldownActive.cooldownDaysRemaining > 0)

            let oldChange = Date().addingTimeInterval(-35 * 86400) // 35 days ago
            let cooldownExpired = CityChangeCooldown(lastChangedAt: oldChange)
            try KlymbAssert.assertTrue(cooldownExpired.canChangeCity, "Cooldown should be expired if changed 35 days ago")

            // 2. Test minimum 3 habits enforcement
            vm.selectedHabitIds = Set([1, 2, 4]) // exactly 3
            vm.toggleHabit(id: 1) // Attempt to remove one
            try KlymbAssert.assertEqual(vm.selectedHabitIds.count, 3, "Should refuse removing habit when count is 3")
            try KlymbAssert.assertNotNil(vm.errorMessage)

            // 3. Test data export
            await vm.exportData()
            try KlymbAssert.assertNotNil(vm.exportFile)
            try KlymbAssert.assertTrue(vm.exportFile?.jsonString.contains("GDPR") == true)

            return TestResult(testName: "SettingsViewModel Tests", passed: true, duration: Date().timeIntervalSince(start))
        } catch {
            return TestResult(testName: "SettingsViewModel Tests", passed: false, failureMessage: "\(error)", duration: Date().timeIntervalSince(start))
        }
    }
}
