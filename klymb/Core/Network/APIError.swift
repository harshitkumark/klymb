//
//  APIError.swift
//  klymb
//
//  Structured error handling mapping PostgreSQL / RPC errors
//  to user-friendly copy (AGENTS.md Rule 14).
//

import Foundation

public enum APIError: LocalizedError, Equatable {
    case unauthorized
    case invalidInput(String)
    case notFound(String)
    case duplicate(String)
    case rateLimited
    case networkError(String)
    case serverError(String)
    case decodingError(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in to continue."
        case .invalidInput(let message):
            return message
        case .notFound(let resource):
            return "\(resource) was not found."
        case .duplicate(let message):
            return message
        case .rateLimited:
            return "You are doing that too fast. Please wait a moment."
        case .networkError(let message):
            return "Connection error: \(message). Please check your internet."
        case .serverError:
            return "Something went wrong on our end. Please try again later."
        case .decodingError:
            return "Failed to load data. Please make sure the app is up to date."
        case .unknown(let message):
            return message
        }
    }

    /// Maps database / RPC error codes to structured APIError
    public static func from(code: String, message: String? = nil) -> APIError {
        switch code {
        case "42501", "ERR_UNAUTHORIZED":
            return .unauthorized
        case "22023", "ERR_INVALID_INPUT":
            return .invalidInput(message ?? "Invalid input.")
        case "23505", "ERR_DUPLICATE", "ERR_USERNAME_TAKEN":
            return .duplicate("That username is already taken.")
        case "23514", "ERR_USERNAME_RESERVED":
            return .invalidInput("That username is reserved. Please choose another.")
        case "ERR_RATE_LIMITED", "over_email_send_rate_limit", "over_request_rate_limit", "429":
            return .rateLimited
        case "user_already_exists", "email_exists":
            return .duplicate("An account with this email already exists. Switch to Sign In instead.")
        case "email_not_confirmed":
            return .invalidInput("Please confirm your email via your inbox link, or turn off 'Confirm email' in Supabase Dashboard -> Authentication -> Providers -> Email.")
        case "invalid_credentials":
            return .invalidInput("Incorrect email or password.")
        case "email_address_invalid", "weak_password", "signup_disabled", "validation_failed", "bad_json", "provider_disabled":
            return .invalidInput(message ?? "Please check your sign-in details and try again.")
        case "P0002", "ERR_NOT_FOUND":
            return .notFound(message ?? "Resource")
        default:
            return .serverError(message ?? "An unexpected error occurred.")
        }
    }
}
