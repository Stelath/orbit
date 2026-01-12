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
    @State private var selectedTab: EmailTab = .general
    @State private var selectedFilteringAccountEmail: String = ""
    @State private var enabledFoldersByAccount: [String: Set<String>] = [:]

    var body: some View {
        VStack(spacing: 16) {
            Picker("Email View", selection: $selectedTab) {
                ForEach(EmailTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            if selectedTab == .general {
                generalContent
            } else {
                emailFilteringContent
            }
        }
        .padding()
        .onAppear {
            viewModel.calculateStorageUsed(context: modelContext)
            ensureFilteringAccountSelection()
        }
        .onChange(of: accounts) { _, _ in
            ensureFilteringAccountSelection()
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
    }

    // MARK: - General Tab

    private var generalContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Connected accounts status
                accountsStatusSection

                // Download settings
                downloadSection

                // Sync settings
                syncSettingsSection

                // Storage management
                storageSection
            }
        }
    }

    // MARK: - Email Filtering Tab

    private var emailFilteringContent: some View {
        VStack(spacing: 16) {
            if accounts.isEmpty {
                Text("Connect a Google account to configure filtering.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GroupBox {
                    if availableFolderTree.isEmpty {
                        Text("Download emails to see available folders.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            OutlineGroup(availableFolderTree, children: \.childrenOptional) { node in
                                Toggle(isOn: bindingForFolder(node.fullPath)) {
                                    Label {
                                        Text(node.displayName)
                                    } icon: {
                                        Image(systemName: folderIconName(for: node))
                                    }
                                }
                            }
                        }
                        .listStyle(.inset)
                    }
                } label: {
                    Text("Email Folders")
                        .font(.headline)
                }

                GroupBox {
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(spacing: 12) {
                            ForEach(accounts, id: \.email) { account in
                                Button {
                                    selectedFilteringAccountEmail = account.email
                                } label: {
                                    Text(account.formattedDisplayName)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedFilteringAccountEmail == account.email ? Color.accentColor.opacity(0.2) : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } label: {
                    Text("Accounts")
                        .font(.headline)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Filtering Helpers

    private var availableFolderTree: [FolderNode] {
        guard !selectedFilteringAccountEmail.isEmpty else {
            return []
        }

        let labels = downloadedEmails
            .filter { $0.googleAccountEmail == selectedFilteringAccountEmail }
            .flatMap { $0.labels }

        var allLabels = Set(labels)
        defaultFolderOrder.forEach { allLabels.insert($0) }
        return FolderNode.buildTree(from: Array(allLabels))
    }

    private var defaultFolderOrder: [String] {
        [
            "INBOX",
            "IMPORTANT",
            "STARRED",
            "SENT",
            "DRAFT",
            "ARCHIVE",
            "SPAM",
            "TRASH"
        ]
    }

    private func ensureFilteringAccountSelection() {
        if selectedFilteringAccountEmail.isEmpty {
            selectedFilteringAccountEmail = accounts.first?.email ?? ""
        } else if !accounts.contains(where: { $0.email == selectedFilteringAccountEmail }) {
            selectedFilteringAccountEmail = accounts.first?.email ?? ""
        }
    }

    private func bindingForFolder(_ folder: String) -> Binding<Bool> {
        Binding(
            get: {
                enabledFoldersByAccount[selectedFilteringAccountEmail, default: []].contains(folder)
            },
            set: { isEnabled in
                var folders = enabledFoldersByAccount[selectedFilteringAccountEmail, default: []]
                if isEnabled {
                    folders.insert(folder)
                } else {
                    folders.remove(folder)
                }
                enabledFoldersByAccount[selectedFilteringAccountEmail] = folders
            }
        )
    }

    private func folderIconName(for node: FolderNode) -> String {
        switch node.fullPath.uppercased() {
        case "INBOX": return "tray"
        case "IMPORTANT": return "flag"
        case "STARRED": return "star"
        case "SENT": return "paperplane"
        case "DRAFT": return "pencil"
        case "ARCHIVE": return "archivebox"
        case "SPAM": return "exclamationmark.triangle"
        case "TRASH": return "trash"
        default:
            return node.children.isEmpty ? "folder" : "folder.fill"
        }
    }
}

private enum EmailTab: String, CaseIterable {
    case general
    case filtering

    var title: String {
        switch self {
        case .general:
            return "General"
        case .filtering:
            return "Email Filtering"
        }
    }
}

private struct FolderNode: Identifiable {
    let id: String
    let name: String
    let fullPath: String
    let children: [FolderNode]
    var childrenOptional: [FolderNode]? { children.isEmpty ? nil : children }

    var displayName: String {
        switch name.uppercased() {
        case "INBOX": return "Inbox"
        case "IMPORTANT": return "Important"
        case "STARRED": return "Starred"
        case "SENT": return "Sent"
        case "DRAFT": return "Drafts"
        case "ARCHIVE": return "Archive"
        case "SPAM": return "Spam"
        case "TRASH": return "Trash"
        default:
            return name.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    static func buildTree(from labels: [String]) -> [FolderNode] {
        var root: [String: FolderBuilder] = [:]

        for label in labels {
            let components = label.split(separator: "/").map(String.init)
            guard let first = components.first else { continue }
            if root[first] == nil {
                root[first] = FolderBuilder(name: first)
            }
            root[first]?.insert(path: Array(components.dropFirst()))
        }

        return root.values
            .map { $0.build(parentPath: nil) }
            .sorted { lhs, rhs in
                if lhs.name == rhs.name { return false }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }
}

private struct FolderBuilder {
    let name: String
    var children: [String: FolderBuilder] = [:]

    mutating func insert(path: [String]) {
        guard let next = path.first else { return }
        if children[next] == nil {
            children[next] = FolderBuilder(name: next)
        }
        children[next]?.insert(path: Array(path.dropFirst()))
    }

    func build(parentPath: String?) -> FolderNode {
        let fullPath: String
        if let parentPath, !parentPath.isEmpty {
            fullPath = "\(parentPath)/\(name)"
        } else {
            fullPath = name
        }

        let childNodes = children.values.map { $0.build(parentPath: fullPath) }
        return FolderNode(
            id: fullPath,
            name: name,
            fullPath: fullPath,
            children: childNodes.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EmailView()
            .modelContainer(for: [GoogleAccount.self, DownloadedEmail.self, SpamFilterRule.self], inMemory: true)
    }
}
