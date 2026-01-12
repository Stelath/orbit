//
//  EmailView.swift
//  orbit
//
//  Email management view with download and sync capabilities
//

import SwiftUI
import SwiftData

struct EmailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [GoogleAccount]
    @Query private var downloadedEmails: [DownloadedEmail]
    @State private var viewModel = EmailManagementViewModel()
    @State private var showingSpamFilter = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Connected accounts status
                accountsStatusSection

                // Download settings
                downloadSection

                // Sync settings
                syncSettingsSection

                // Storage management
                storageSection

                // Spam filtering
                spamFilterSection
            }
            .padding()
        }
        .onAppear {
            viewModel.calculateStorageUsed(context: modelContext)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showingSpamFilter) {
            NavigationStack {
                SpamFilterView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingSpamFilter = false
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Email Management", systemImage: "envelope")
                .font(.title)
                .fontWeight(.bold)

            Text("Download and manage your emails locally")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Accounts Status Section

    private var accountsStatusSection: some View {
        GroupBox {
            HStack {
                Label("\(accounts.count) Google account(s) connected", systemImage: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(accounts.isEmpty ? .secondary : .primary)

                Spacer()

                NavigationLink(destination: AccountsView()) {
                    Text(accounts.isEmpty ? "Connect Account" : "Manage Accounts")
                }
                .buttonStyle(.bordered)
            }
        } label: {
            Text("Connected Accounts")
                .font(.headline)
        }
    }

    // MARK: - Download Section

    private var downloadSection: some View {
        GroupBox {
            VStack(spacing: 16) {
                // Download button
                if viewModel.isDownloading {
                    VStack(spacing: 12) {
                        ProgressView(value: viewModel.downloadProgress)

                        Text(viewModel.downloadStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        Task {
                            await viewModel.downloadAllEmails(accounts: accounts, context: modelContext)
                        }
                    } label: {
                        Label("Download All Emails", systemImage: "arrow.down.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(accounts.isEmpty)
                }

                Divider()

                // Status information
                VStack(spacing: 8) {
                    HStack {
                        Label("Total Emails", systemImage: "envelope.fill")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(downloadedEmails.count)")
                            .fontWeight(.semibold)
                    }

                    if let lastDownload = viewModel.lastDownloadDate {
                        HStack {
                            Label("Last Download", systemImage: "clock.fill")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(lastDownload, style: .relative)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .font(.subheadline)

                if accounts.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Connect a Google account to download emails")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
        } label: {
            Text("Download Settings")
                .font(.headline)
        }
    }

    // MARK: - Sync Settings Section

    private var syncSettingsSection: some View {
        GroupBox {
            VStack(spacing: 12) {
                Toggle(isOn: $viewModel.autoSyncEnabled) {
                    Label("Auto-sync on startup", systemImage: "arrow.clockwise")
                }

                Divider()

                HStack {
                    Label("Sync frequency", systemImage: "timer")
                    Spacer()
                    Picker("Frequency", selection: $viewModel.syncFrequency) {
                        ForEach(SyncFrequency.allCases) { frequency in
                            Text(frequency.rawValue).tag(frequency)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 150)
                }

                Divider()

                Toggle(isOn: $viewModel.downloadAttachments) {
                    Label("Download attachments", systemImage: "paperclip")
                }
                .disabled(true) // Future feature
                .opacity(0.5)
            }
        } label: {
            Text("Sync Settings")
                .font(.headline)
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        GroupBox {
            VStack(spacing: 16) {
                // Storage info
                VStack(spacing: 8) {
                    HStack {
                        Label("Storage Used", systemImage: "internaldrive.fill")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f MB", viewModel.storageUsedMB))
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Label("Emails Stored", systemImage: "tray.full.fill")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(downloadedEmails.count)")
                            .fontWeight(.semibold)
                    }
                }
                .font(.subheadline)

                Divider()

                // Management actions
                VStack(spacing: 8) {
                    Button(role: .destructive) {
                        viewModel.clearAllEmails(context: modelContext)
                    } label: {
                        Label("Clear All Downloaded Emails", systemImage: "trash.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(downloadedEmails.isEmpty)

                    HStack {
                        Text("Keep emails from last")
                            .foregroundStyle(.secondary)

                        Stepper("\(viewModel.keepDaysCount) days", value: $viewModel.keepDaysCount, in: 7...365, step: 7)
                            .labelsHidden()

                        Text("\(viewModel.keepDaysCount) days")
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)

                    Button {
                        viewModel.clearOldEmails(olderThan: viewModel.keepDaysCount, context: modelContext)
                    } label: {
                        Label("Clear Emails Older Than \(viewModel.keepDaysCount) Days", systemImage: "calendar.badge.minus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(downloadedEmails.isEmpty)
                }
            }
        } label: {
            Text("Storage Management")
                .font(.headline)
        }
    }

    // MARK: - Spam Filter Section

    private var spamFilterSection: some View {
        GroupBox {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Spam Filtering")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Manage spam filter rules")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        showingSpamFilter = true
                    } label: {
                        Label("Manage Rules", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.bordered)
                }
            }
        } label: {
            Text("Spam Filtering")
                .font(.headline)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EmailView()
            .modelContainer(for: [GoogleAccount.self, DownloadedEmail.self, SpamFilterRule.self], inMemory: true)
    }
}
