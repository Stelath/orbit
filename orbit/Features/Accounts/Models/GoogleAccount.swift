//
//  GoogleAccount.swift
//  orbit
//
//  Google account model for storing account metadata
//

import Foundation
import SwiftData

/// Google account model
/// Note: OAuth tokens are stored separately in Keychain, not in this model
@Model
final class GoogleAccount {
    /// Unique identifier
    var id: UUID

    /// User's email address
    var email: String

    /// Display name (from Google profile)
    var displayName: String?

    /// Profile image URL
    var profileImageURL: String?

    /// Google user ID (unique identifier from Google)
    var googleUserID: String

    /// Whether the account is currently connected
    var isConnected: Bool

    /// Whether the account has granted Calendar access
    var hasCalendarAccess: Bool

    /// Whether the account has granted Gmail access
    var hasGmailAccess: Bool

    /// Last sync timestamp
    var lastSyncDate: Date?

    /// When the account was added
    var dateAdded: Date

    // MARK: - Initialization

    init(
        email: String,
        googleUserID: String,
        displayName: String? = nil,
        profileImageURL: String? = nil,
        isConnected: Bool = true,
        hasCalendarAccess: Bool = false,
        hasGmailAccess: Bool = false
    ) {
        self.id = UUID()
        self.email = email
        self.googleUserID = googleUserID
        self.displayName = displayName
        self.profileImageURL = profileImageURL
        self.isConnected = isConnected
        self.hasCalendarAccess = hasCalendarAccess
        self.hasGmailAccess = hasGmailAccess
        self.lastSyncDate = nil
        self.dateAdded = Date()
    }

    // MARK: - Computed Properties

    /// Formatted display name
    var formattedDisplayName: String {
        return displayName ?? email
    }

    /// Relative date string for last sync
    var lastSyncFormatted: String {
        guard let lastSync = lastSyncDate else {
            return "Never synced"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
}
