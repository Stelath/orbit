//
//  DownloadedEmail.swift
//  orbit
//
//  Model for storing downloaded emails locally
//

import Foundation
import SwiftData

/// Downloaded email model
@Model
final class DownloadedEmail {
    /// Unique identifier
    var id: UUID

    /// Gmail message ID
    var messageID: String

    /// Which Google account this email came from
    var googleAccountEmail: String

    /// Email subject
    var subject: String

    /// Sender email address
    var fromEmail: String

    /// Sender display name
    var fromName: String?

    /// Recipient email addresses
    var toEmails: [String]

    /// CC email addresses
    var ccEmails: [String]

    /// Email date
    var date: Date

    /// Plain text body
    var bodyPlainText: String?

    /// HTML body
    var bodyHTML: String?

    /// Gmail snippet (preview text)
    var snippet: String

    /// Gmail labels
    var labels: [String]

    /// Whether the email is read
    var isRead: Bool

    /// Whether the email is starred
    var isStarred: Bool

    /// When the email was downloaded
    var downloadedAt: Date

    // MARK: - Initialization

    init(
        messageID: String,
        googleAccountEmail: String,
        subject: String,
        fromEmail: String,
        fromName: String? = nil,
        toEmails: [String] = [],
        ccEmails: [String] = [],
        date: Date,
        bodyPlainText: String? = nil,
        bodyHTML: String? = nil,
        snippet: String,
        labels: [String] = [],
        isRead: Bool = false,
        isStarred: Bool = false
    ) {
        self.id = UUID()
        self.messageID = messageID
        self.googleAccountEmail = googleAccountEmail
        self.subject = subject
        self.fromEmail = fromEmail
        self.fromName = fromName
        self.toEmails = toEmails
        self.ccEmails = ccEmails
        self.date = date
        self.bodyPlainText = bodyPlainText
        self.bodyHTML = bodyHTML
        self.snippet = snippet
        self.labels = labels
        self.isRead = isRead
        self.isStarred = isStarred
        self.downloadedAt = Date()
    }

    // MARK: - Computed Properties

    /// Formatted sender name
    var senderName: String {
        return fromName ?? fromEmail
    }

    /// Relative date string
    var dateFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Whether this email is in inbox
    var isInInbox: Bool {
        return labels.contains("INBOX")
    }

    /// Whether this email is spam
    var isSpam: Bool {
        return labels.contains("SPAM")
    }

    /// Whether this email is important
    var isImportant: Bool {
        return labels.contains("IMPORTANT")
    }

    /// Size estimate in bytes (rough approximation)
    var sizeEstimate: Int {
        var size = 0
        if let plainText = bodyPlainText {
            size += plainText.utf8.count
        }
        if let htmlText = bodyHTML {
            size += htmlText.utf8.count
        }
        size += subject.utf8.count
        size += snippet.utf8.count
        return size
    }
}
