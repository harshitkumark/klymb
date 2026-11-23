//
//  VersionModels.swift
//  klymb
//
//  App version models and update requirement logic (PRD §F16 & Architecture §8.2).
//  Follows AGENTS.md Rules 13, 14.
//

import Foundation

public struct AppVersionInfo: Equatable, Sendable {
    public let currentVersion: String
    public let currentBuild: Int
    public let minSupportedVersion: String
    public let minSupportedBuild: Int
    public let appStoreURL: URL
    public let releaseNotes: String?

    public init(
        currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
        currentBuild: Int = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "42") ?? 42,
        minSupportedVersion: String = "1.0.0",
        minSupportedBuild: Int = 40,
        appStoreURL: URL = URL(string: "https://apps.apple.com/app/klymb/id6739000000")!,
        releaseNotes: String? = "Performance improvements, enhanced anti-cheat validation, and updated seasonal challenge mechanics."
    ) {
        self.currentVersion = currentVersion
        self.currentBuild = currentBuild
        self.minSupportedVersion = minSupportedVersion
        self.minSupportedBuild = minSupportedBuild
        self.appStoreURL = appStoreURL
        self.releaseNotes = releaseNotes
    }

    public var isUpdateRequired: Bool {
        return currentBuild < minSupportedBuild
    }
}
