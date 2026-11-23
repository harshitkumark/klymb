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
    public var forceUpdateEnabled: Bool

    public init(
        currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
        currentBuild: Int = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1") ?? 1,
        minSupportedVersion: String = "1.0.0",
        minSupportedBuild: Int = 1,
        appStoreURL: URL = URL(string: "https://apps.apple.com/app/klymb/id6739000000")!,
        releaseNotes: String? = "Performance improvements, enhanced anti-cheat validation, and updated seasonal challenge mechanics.",
        forceUpdateEnabled: Bool = false
    ) {
        self.currentVersion = currentVersion
        self.currentBuild = currentBuild
        self.minSupportedVersion = minSupportedVersion
        self.minSupportedBuild = minSupportedBuild
        self.appStoreURL = appStoreURL
        self.releaseNotes = releaseNotes
        self.forceUpdateEnabled = forceUpdateEnabled
    }

    public var isUpdateRequired: Bool {
        #if DEBUG
        // Never block developers during local testing or preview builds
        return false
        #else
        return forceUpdateEnabled && (currentBuild < minSupportedBuild)
        #endif
    }
}
