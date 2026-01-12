//
//  AccountsViewModel.swift
//  orbit
//
//  ViewModel for managing Google account connections
//

import Foundation
import SwiftData
import Observation

/// ViewModel for Accounts feature
@Observable
final class AccountsViewModel {
    // MARK: - Properties

    private let oauthManager = GoogleOAuthManager()

    /// Whether a sign-in operation is in progress
    var isSigningIn: Bool = false

    /// Error message to display
    var errorMessage: String?

    /// Whether to show permissions info sheet
    var showingPermissionsInfo: Bool = false

    // MARK: - Public Methods

    /// Sign in with Google and create account
    /// - Parameter context: SwiftData model context
    func signInWithGoogle(context: ModelContext) async {
        await MainActor.run {
            isSigningIn = true
            errorMessage = nil
        }

        defer {
            Task { @MainActor in
                isSigningIn = false
            }
        }

        do {
            // Perform OAuth sign-in
            let userInfo = try await oauthManager.signIn()

            // Check if account already exists
            let userID = userInfo.userID
            let descriptor = FetchDescriptor<GoogleAccount>(
                predicate: #Predicate { account in
                    account.googleUserID == userID
                }
            )
            let existingAccount = try? context.fetch(descriptor).first

            if let existing = existingAccount {
                // Update existing account
                await MainActor.run {
                    existing.isConnected = true
                    existing.displayName = userInfo.displayName
                    existing.lastSyncDate = Date()

                    // Check permissions
                    let permissions = oauthManager.checkPermissions(for: userInfo.userID)
                    existing.hasCalendarAccess = permissions.hasCalendarAccess
                    existing.hasGmailAccess = permissions.hasGmailAccess
                }
            } else {
                // Create new account
                let permissions = oauthManager.checkPermissions(for: userInfo.userID)

                let newAccount = GoogleAccount(
                    email: userInfo.email,
                    googleUserID: userInfo.userID,
                    displayName: userInfo.displayName,
                    isConnected: true,
                    hasCalendarAccess: permissions.hasCalendarAccess,
                    hasGmailAccess: permissions.hasGmailAccess
                )

                await MainActor.run {
                    context.insert(newAccount)
                }
            }

            // Save context
            try await MainActor.run {
                try context.save()
            }

        } catch {
            await MainActor.run {
                errorMessage = "Failed to sign in: \(error.localizedDescription)"
            }
        }
    }

    /// Disconnect a Google account
    /// - Parameters:
    ///   - account: Account to disconnect
    ///   - context: SwiftData model context
    func disconnectAccount(_ account: GoogleAccount, context: ModelContext) {
        do {
            // Sign out and remove tokens
            try oauthManager.signOut(userID: account.googleUserID)

            // Delete account from database
            context.delete(account)
            try context.save()

        } catch {
            errorMessage = "Failed to disconnect: \(error.localizedDescription)"
        }
    }

    /// Refresh account status and permissions
    /// - Parameter account: Account to refresh
    func refreshAccountStatus(_ account: GoogleAccount) async {
        do {
            // Refresh token if needed
            try await oauthManager.refreshTokenIfNeeded(for: account.googleUserID)

            // Update permissions
            let permissions = oauthManager.checkPermissions(for: account.googleUserID)

            await MainActor.run {
                account.hasCalendarAccess = permissions.hasCalendarAccess
                account.hasGmailAccess = permissions.hasGmailAccess
                account.lastSyncDate = Date()
            }

        } catch {
            await MainActor.run {
                errorMessage = "Failed to refresh account: \(error.localizedDescription)"
            }
        }
    }

    /// Re-authenticate an account (for when permissions are missing)
    /// - Parameters:
    ///   - account: Account to re-authenticate
    ///   - context: SwiftData model context
    func reAuthenticateAccount(_ account: GoogleAccount, context: ModelContext) async {
        // For now, disconnect and sign in again
        // This will prompt the user to grant permissions again
        disconnectAccount(account, context: context)
        await signInWithGoogle(context: context)
    }

    /// Check if all required permissions are granted
    /// - Parameter account: Account to check
    /// - Returns: True if both Calendar and Gmail access are granted
    func hasAllPermissions(_ account: GoogleAccount) -> Bool {
        return account.hasCalendarAccess && account.hasGmailAccess
    }
}
