//
//  AppleSignInHelper.swift
//  klymb
//
//  Manages Sign in with Apple nonce generation and cryptographic hashing
//  matching Apple's security best practices.
//

import Foundation
import CryptoKit
import AuthenticationServices

public final class AppleSignInHelper {
    public static let shared = AppleSignInHelper()

    private var currentNonce: String?

    private init() {}

    /// Generates a random cryptographic nonce and stores it for verification
    public func generateNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    /// Verifies and returns the unhashed nonce for backend token validation
    public func consumeNonce() -> String? {
        defer { currentNonce = nil }
        return currentNonce
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
