//
//  EmailManagementViewModel.swift
//  orbit
//
//  ViewModel for email downloading and management
//

import Foundation
import SwiftData
import Observation

/// Sync frequency options
enum SyncFrequency: String, CaseIterable, Identifiable {
    case manual = "Manual"
    case hourly = "Every Hour"
    case daily = "Daily"

    var id: String { rawValue }
}

/// ViewModel for Email Management feature
@Observable
final class EmailManagementViewModel {
    // MARK: - Properties

    private let gmailClient = GmailAPIClient()
    private let secureStorage = SecureStorage()

    /// Whether emails are currently being downloaded
    var isDownloading: Bool = false

    /// Download progress (0.0 to 1.0)
    var downloadProgress: Double = 0.0

    /// Current download status message
    var downloadStatus: String = ""

    /// Last download timestamp
    var lastDownloadDate: Date?

    /// Total emails downloaded
    var totalEmailsDownloaded: Int = 0

    /// Storage used in MB
    var storageUsedMB: Double = 0.0

    /// Auto-sync enabled
    var autoSyncEnabled: Bool = false

    /// Sync frequency
    var syncFrequency: SyncFrequency = .manual

    /// Download attachments
    var downloadAttachments: Bool = false

    /// Keep emails from last N days
    var keepDaysCount: Int = 90

    /// Error message
    var errorMessage: String?

    // MARK: - Initialization

    init() {
        loadPreferences()
    }

    // MARK: - Public Methods

    /// Download all emails from all connected accounts
    /// - Parameter accounts: List of Google accounts to download from
    func downloadAllEmails(accounts: [GoogleAccount], context: ModelContext) async {
        guard !accounts.isEmpty else {
            await MainActor.run {
                errorMessage = "No Google accounts connected. Please connect an account first."
            }
            return
        }

        await MainActor.run {
            isDownloading = true
            downloadProgress = 0.0
            errorMessage = nil
        }

        defer {
            Task { @MainActor in
                isDownloading = false
                lastDownloadDate = Date()
                savePreferences()
            }
        }

        let totalAccounts = accounts.count
        var processedAccounts = 0
        var totalDownloaded = 0

        // Download from each account
        for account in accounts {
            await MainActor.run {
                downloadStatus = "Downloading from \(account.email)..."
            }

            do {
                let count = try await downloadEmailsFromAccount(account, context: context)
                totalDownloaded += count
                processedAccounts += 1

                await MainActor.run {
                    downloadProgress = Double(processedAccounts) / Double(totalAccounts)
                }

            } catch {
                await MainActor.run {
                    errorMessage = "Failed to download from \(account.email): \(error.localizedDescription)"
                }
                // Continue with other accounts
            }
        }

        await MainActor.run {
            downloadStatus = "Downloaded \(totalDownloaded) emails from \(processedAccounts) accounts"
            totalEmailsDownloaded = totalDownloaded
            calculateStorageUsed(context: context)
        }
    }

    /// Clear all downloaded emails
    /// - Parameter context: SwiftData model context
    func clearAllEmails(context: ModelContext) {
        do {
            let fetchDescriptor = FetchDescriptor<DownloadedEmail>()
            let allEmails = try context.fetch(fetchDescriptor)

            for email in allEmails {
                context.delete(email)
            }

            try context.save()

            totalEmailsDownloaded = 0
            storageUsedMB = 0.0
            lastDownloadDate = nil

        } catch {
            errorMessage = "Failed to clear emails: \(error.localizedDescription)"
        }
    }

    /// Clear emails older than specified days
    /// - Parameters:
    ///   - days: Number of days to keep
    ///   - context: SwiftData model context
    func clearOldEmails(olderThan days: Int, context: ModelContext) {
        do {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

            let fetchDescriptor = FetchDescriptor<DownloadedEmail>(
                predicate: #Predicate<DownloadedEmail> { email in
                    email.date < cutoffDate
                }
            )

            let oldEmails = try context.fetch(fetchDescriptor)

            for email in oldEmails {
                context.delete(email)
            }

            try context.save()

            calculateStorageUsed(context: context)

        } catch {
            errorMessage = "Failed to clear old emails: \(error.localizedDescription)"
        }
    }

    /// Calculate storage used by downloaded emails
    /// - Parameter context: SwiftData model context
    func calculateStorageUsed(context: ModelContext) {
        do {
            let fetchDescriptor = FetchDescriptor<DownloadedEmail>()
            let allEmails = try context.fetch(fetchDescriptor)

            totalEmailsDownloaded = allEmails.count

            var totalBytes = 0
            for email in allEmails {
                totalBytes += email.sizeEstimate
            }

            storageUsedMB = Double(totalBytes) / 1_048_576.0 // Convert to MB

        } catch {
            errorMessage = "Failed to calculate storage: \(error.localizedDescription)"
        }
    }

    // MARK: - Private Methods

    /// Download emails from a single account
    /// - Parameters:
    ///   - account: Google account to download from
    ///   - context: SwiftData model context
    /// - Returns: Number of emails downloaded
    private func downloadEmailsFromAccount(_ account: GoogleAccount, context: ModelContext) async throws -> Int {
        // Get access token
        let tokenKey = SecureStorage.googleAccessTokenKey(for: account.googleUserID)

        guard case .success(let accessToken) = secureStorage.retrieve(key: tokenKey) else {
            throw EmailDownloadError.noAccessToken
        }

        var totalDownloaded = 0
        var pageToken: String?

        // Paginate through messages
        repeat {
            let messageList = try await gmailClient.fetchMessages(
                accessToken: accessToken,
                maxResults: 100,
                pageToken: pageToken
            )

            guard let messages = messageList.messages else {
                break
            }

            // Fetch full message details for each
            for messageRef in messages {
                do {
                    let message = try await gmailClient.getMessage(
                        id: messageRef.id,
                        accessToken: accessToken
                    )

                    // Parse and store email
                    if let email = gmailClient.parseEmail(message: message, accountEmail: account.email) {
                        // Capture values to use inside the predicate (avoid comparing key paths)
                        let targetMessageID = email.messageID
                        let targetAccountEmail = email.googleAccountEmail

                        let predicate = #Predicate<DownloadedEmail> { e in
                            e.messageID == targetMessageID && e.googleAccountEmail == targetAccountEmail
                        }

                        let fetchDescriptor: FetchDescriptor<DownloadedEmail> = FetchDescriptor(
                            predicate: predicate
                        )

                        let existingEmail = try? context.fetch(fetchDescriptor).first

                        if existingEmail == nil {
                            await MainActor.run {
                                context.insert(email)
                            }
                            totalDownloaded += 1
                        }
                    }

                } catch {
                    // Skip individual failed messages, continue with others
                    print("Failed to download message \(messageRef.id): \(error)")
                    continue
                }
            }

            // Save batch
            try await MainActor.run {
                try context.save()
            }

            pageToken = messageList.nextPageToken

            // Update progress
            await MainActor.run {
                downloadStatus = "Downloaded \(totalDownloaded) emails from \(account.email)..."
            }

        } while pageToken != nil

        // Update account sync date
        await MainActor.run {
            account.lastSyncDate = Date()
        }

        return totalDownloaded
    }

    /// Load preferences from UserDefaults
    private func loadPreferences() {
        let defaults = UserDefaults.standard

        autoSyncEnabled = defaults.bool(forKey: "autoSyncEnabled")
        keepDaysCount = defaults.integer(forKey: "keepDaysCount")
        if keepDaysCount == 0 {
            keepDaysCount = 90 // Default
        }
        downloadAttachments = defaults.bool(forKey: "downloadAttachments")

        if let frequencyRaw = defaults.string(forKey: "syncFrequency"),
           let frequency = SyncFrequency(rawValue: frequencyRaw) {
            syncFrequency = frequency
        }

        if let lastDownload = defaults.object(forKey: "lastDownloadDate") as? Date {
            lastDownloadDate = lastDownload
        }

        totalEmailsDownloaded = defaults.integer(forKey: "totalEmailsDownloaded")
        storageUsedMB = defaults.double(forKey: "storageUsedMB")
    }

    /// Save preferences to UserDefaults
    private func savePreferences() {
        let defaults = UserDefaults.standard

        defaults.set(autoSyncEnabled, forKey: "autoSyncEnabled")
        defaults.set(keepDaysCount, forKey: "keepDaysCount")
        defaults.set(downloadAttachments, forKey: "downloadAttachments")
        defaults.set(syncFrequency.rawValue, forKey: "syncFrequency")
        defaults.set(lastDownloadDate, forKey: "lastDownloadDate")
        defaults.set(totalEmailsDownloaded, forKey: "totalEmailsDownloaded")
        defaults.set(storageUsedMB, forKey: "storageUsedMB")
    }

    // MARK: - Errors

    enum EmailDownloadError: Error, LocalizedError {
        case noAccessToken
        case downloadFailed(String)

        var errorDescription: String? {
            switch self {
            case .noAccessToken:
                return "No access token found. Please reconnect your Google account."
            case .downloadFailed(let message):
                return "Download failed: \(message)"
            }
        }
    }
}

