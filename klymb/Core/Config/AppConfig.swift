//
//  AppConfig.swift
//  klymb
//
//  Application configuration and environment settings.
//  No hardcoded secrets (AGENTS.md Rule 10).
//

import Foundation

public enum AppEnvironment: String {
    case development
    case staging
    case production
}

public struct AppConfig {
    public static let shared = AppConfig()

    public let environment: AppEnvironment
    public let supabaseURL: URL
    public let supabaseAnonKey: String
    public let appBundleID: String

    public init(
        environment: AppEnvironment = .development,
        supabaseURL: URL? = nil,
        supabaseAnonKey: String? = nil
    ) {
        self.environment = environment
        self.appBundleID = Bundle.main.bundleIdentifier ?? "com.klymb.app"

        // Prefer values from Bundle (Info.plist / xcconfig)
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
           let url = URL(string: urlString) {
            self.supabaseURL = url
        } else if let supabaseURL = supabaseURL {
            self.supabaseURL = supabaseURL
        } else {
            // Default local development stack
            self.supabaseURL = URL(string: "http://127.0.0.1:54321")!
        }

        if let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
           !anonKey.isEmpty {
            self.supabaseAnonKey = anonKey
        } else if let supabaseAnonKey = supabaseAnonKey {
            self.supabaseAnonKey = supabaseAnonKey
        } else {
            // Default local development anon key
            self.supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM0NDk2MDB9.dummy"
        }
    }
}
