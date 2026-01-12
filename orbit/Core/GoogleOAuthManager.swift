//
//  GoogleOAuthManager.swift
//  orbit
//
//  Google OAuth 2.0 authentication manager
//

import Foundation
import GoogleSignIn
import SwiftUI
import AppKit
import Observation

/// Manages Google OAuth authentication and token management
@Observable
class GoogleOAuthManager {
    // MARK: - Properties

    private let secureStorage = SecureStorage()

    /// Currently signed-in Google user
    var currentUser: GIDGoogleUser?

    /// Whether a user is currently signed in
    var isSignedIn: Bool {
        return currentUser != nil
    }

    /// Error message for display
    var errorMessage: String?

    // MARK: - OAuth Scopes

    private let requiredScopes = [
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/calendar",
        "openid",
        "profile",
        "email"
    ]

    // MARK: - Initialization

    init() {
        // Restore previous sign-in if exists
        restorePreviousSignIn()
    }

    // MARK: - Public Methods

    /// Sign in with Google OAuth
    /// - Returns: User information including email, name, and user ID
    /// - Throws: OAuth errors
    func signIn() async throws -> (email: String, displayName: String?, userID: String) {
        return try await withCheckedThrowingContinuation { continuation in
            // Get the root window for presenting the sign-in flow
            guard let presentingWindow = getRootViewController() else {
                continuation.resume(throwing: OAuthError.noPresentingViewController)
                return
            }

            // Configure GIDSignIn
            guard let clientID = getClientID() else {
                continuation.resume(throwing: OAuthError.missingClientID)
                return
            }

            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config

            // Start sign-in flow (macOS uses NSWindow)
            GIDSignIn.sharedInstance.signIn(
                withPresenting: presentingWindow,
                hint: nil,
                additionalScopes: requiredScopes
            ) { [weak self] signInResult, error in
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    continuation.resume(throwing: OAuthError.signInFailed(error.localizedDescription))
                    return
                }

                guard let result = signInResult else {
                    continuation.resume(throwing: OAuthError.noResult)
                    return
                }

                // Extract user information
                let user = result.user
                guard let email = user.profile?.email,
                      let userID = user.userID else {
                    continuation.resume(throwing: OAuthError.missingUserInfo)
                    return
                }

                let displayName = user.profile?.name

                // Store tokens
                self?.storeTokens(for: user)

                // Update current user
                self?.currentUser = user

                continuation.resume(returning: (email: email, displayName: displayName, userID: userID))
            }
        }
    }

    /// Sign out and clear stored tokens
    /// - Parameter userID: Google user ID to sign out
    func signOut(userID: String) throws {
        // Delete tokens from keychain
        let accessTokenKey = SecureStorage.googleAccessTokenKey(for: userID)
        let refreshTokenKey = SecureStorage.googleRefreshTokenKey(for: userID)

        _ = secureStorage.delete(key: accessTokenKey)
        _ = secureStorage.delete(key: refreshTokenKey)

        // Sign out from GoogleSignIn SDK
        GIDSignIn.sharedInstance.signOut()

        // Clear current user
        currentUser = nil
    }

    /// Get access token for a user
    /// - Parameter userID: Google user ID
    /// - Returns: Access token if available
    func getAccessToken(for userID: String) -> String? {
        let tokenKey = SecureStorage.googleAccessTokenKey(for: userID)

        switch secureStorage.retrieve(key: tokenKey) {
        case .success(let token):
            return token
        case .failure:
            return nil
        }
    }

    /// Refresh token if needed
    /// - Parameter userID: Google user ID
    func refreshTokenIfNeeded(for userID: String) async throws {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw OAuthError.notSignedIn
        }

        // GoogleSignIn SDK handles token refresh automatically
        // Check if token needs refresh
        if currentUser.accessToken.expirationDate ?? Date() < Date() {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                currentUser.refreshTokensIfNeeded { [weak self] user, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let user = user else {
                        continuation.resume(throwing: OAuthError.noResult)
                        return
                    }

                    // Store refreshed tokens
                    self?.storeTokens(for: user)
                    self?.currentUser = user

                    continuation.resume()
                }
            }
        }
    }

    /// Check if user has granted specific scopes
    /// - Parameter userID: Google user ID
    /// - Returns: Tuple with calendar and gmail access status
    func checkPermissions(for userID: String) -> (hasCalendarAccess: Bool, hasGmailAccess: Bool) {
        guard let user = currentUser else {
            return (false, false)
        }

        let grantedScopes = user.grantedScopes ?? []

        let hasCalendar = grantedScopes.contains("https://www.googleapis.com/auth/calendar")
        let hasGmail = grantedScopes.contains("https://www.googleapis.com/auth/gmail.readonly")

        return (hasCalendarAccess: hasCalendar, hasGmailAccess: hasGmail)
    }

    // MARK: - Private Methods

    /// Restore previous sign-in session if exists
    private func restorePreviousSignIn() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            if let user = user {
                self?.currentUser = user
            }
        }
    }

    /// Store OAuth tokens in secure storage
    /// - Parameter user: Google user with tokens
    private func storeTokens(for user: GIDGoogleUser) {
        guard let userID = user.userID else { return }

        let accessTokenKey = SecureStorage.googleAccessTokenKey(for: userID)
        let refreshTokenKey = SecureStorage.googleRefreshTokenKey(for: userID)

        // Store access token
        let accessToken = user.accessToken.tokenString
        _ = secureStorage.save(key: accessTokenKey, value: accessToken)

        // Store refresh token
        let refreshToken = user.refreshToken.tokenString
        _ = secureStorage.save(key: refreshTokenKey, value: refreshToken)
    }

    /// Get client ID from Info.plist
    /// - Returns: OAuth client ID
    private func getClientID() -> String? {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            errorMessage = "Missing GIDClientID in Info.plist"
            return nil
        }
        return clientID
    }

    /// Get root window for presenting OAuth flow (macOS)
    /// - Returns: Root window
    private func getRootViewController() -> NSWindow? {
        #if os(macOS)
        return NSApplication.shared.keyWindow
        #else
        return nil
        #endif
    }

    // MARK: - Errors

    enum OAuthError: Error, LocalizedError {
        case noPresentingViewController
        case missingClientID
        case signInFailed(String)
        case noResult
        case missingUserInfo
        case notSignedIn

        var errorDescription: String? {
            switch self {
            case .noPresentingViewController:
                return "Could not find presenting view controller"
            case .missingClientID:
                return "OAuth Client ID not configured in Info.plist"
            case .signInFailed(let message):
                return "Sign in failed: \(message)"
            case .noResult:
                return "No result from sign in"
            case .missingUserInfo:
                return "Could not retrieve user information"
            case .notSignedIn:
                return "User not signed in"
            }
        }
    }
}

