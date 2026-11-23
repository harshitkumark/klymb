//
//  AppTestRunner.swift
//  klymb
//
//  Central automated test suite orchestrator for unit, integration,
//  and architectural compliance validation (PRD §F19).
//  Follows AGENTS.md Rules 1, 2, 5, 17, 18.
//

import Foundation

@MainActor
public final class AppTestRunner {
    public static let shared = AppTestRunner()

    public init() {}

    @discardableResult
    public static func runAllSuites() async -> (total: Int, passed: Int, failed: Int, results: [TestResult]) {
        print("\n==================================================")
        print("🚀 KLYMB AUTOMATED TEST SUITE RUNNER")
        print("==================================================")

        var allResults: [TestResult] = []

        // 1. Architectural & Security Rules (AGENTS.md Rules 1, 2, 17)
        let ruleResults = await RuleComplianceTests.runAll()
        allResults.append(contentsOf: ruleResults)

        // 2. ViewModel Tests across all 5 Tabs & Settings
        let vmResults = await ViewModelTests.runAll()
        allResults.append(contentsOf: vmResults)

        let total = allResults.count
        let passed = allResults.filter { $0.passed }.count
        let failed = total - passed

        print("\n---------------- TEST RESULTS ----------------")
        for res in allResults {
            let symbol = res.passed ? "✅ PASS" : "❌ FAIL"
            let durationMs = String(format: "%.1fms", res.duration * 1000)
            print("\(symbol) [\(durationMs)] - \(res.testName)")
            if let failure = res.failureMessage {
                print("   ⚠️ Reason: \(failure)")
            }
        }
        print("----------------------------------------------")
        print("Summary: \(passed)/\(total) passed, \(failed) failed.")
        print("==================================================\n")

        return (total: total, passed: passed, failed: failed, results: allResults)
    }
}
