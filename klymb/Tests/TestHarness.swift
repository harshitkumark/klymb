//
//  TestHarness.swift
//  klymb
//
//  Lightweight, standalone test runner and assertion engine (PRD §F19).
//  Follows AGENTS.md Rules 13, 14, 15, 16.
//

import Foundation

public struct TestFailure: Error, CustomStringConvertible {
    public let message: String
    public let file: StaticString
    public let line: UInt

    public var description: String {
        "\(file):\(line): \(message)"
    }
}

public struct TestResult: Sendable {
    public let testName: String
    public let passed: Bool
    public let failureMessage: String?
    public let duration: TimeInterval

    public init(testName: String, passed: Bool, failureMessage: String? = nil, duration: TimeInterval = 0) {
        self.testName = testName
        self.passed = passed
        self.failureMessage = failureMessage
        self.duration = duration
    }
}

public final class KlymbAssert {
    public static func assertEqual<T: Equatable>(
        _ actual: T,
        _ expected: T,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        if actual != expected {
            let msg = message.isEmpty ? "Expected \(expected), but got \(actual)" : message
            throw TestFailure(message: msg, file: file, line: line)
        }
    }

    public static func assertTrue(
        _ condition: Bool,
        _ message: String = "Expected condition to be true",
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        if !condition {
            throw TestFailure(message: message, file: file, line: line)
        }
    }

    public static func assertFalse(
        _ condition: Bool,
        _ message: String = "Expected condition to be false",
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        if condition {
            throw TestFailure(message: message, file: file, line: line)
        }
    }

    public static func assertNotNil<T>(
        _ value: T?,
        _ message: String = "Expected value not to be nil",
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        if value == nil {
            throw TestFailure(message: message, file: file, line: line)
        }
    }

    public static func assertNil<T>(
        _ value: T?,
        _ message: String = "Expected value to be nil",
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        if value != nil {
            throw TestFailure(message: message, file: file, line: line)
        }
    }
}
