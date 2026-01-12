//
//  AccountsView.swift
//  orbit
//
//  View for managing Google account connections
//

import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [GoogleAccount]
    @State private var viewModel = AccountsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Accounts list or empty state
                if accounts.isEmpty {
                    emptyState
                } else {
                    accountsList
                }
            }
            .padding()
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

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Connected Accounts", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                // Sign in button
                Button {
                    Task {
                        await viewModel.signInWithGoogle(context: modelContext)
                    }
                } label: {
                    Label("Sign in with Google", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSigningIn)
            }

            Text("Connect Google accounts to access Calendar and Gmail")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No accounts connected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Sign in with your Google account to get started")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.signInWithGoogle(context: modelContext)
                }
            } label: {
                Label("Connect your first Google account", systemImage: "arrow.right.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isSigningIn)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Accounts List

    private var accountsList: some View {
        VStack(spacing: 16) {
            ForEach(accounts) { account in
                GoogleAccountCard(
                    account: account,
                    viewModel: viewModel,
                    modelContext: modelContext
                )
            }
        }
    }
}

// MARK: - Google Account Card

struct GoogleAccountCard: View {
    let account: GoogleAccount
    let viewModel: AccountsViewModel
    let modelContext: ModelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Profile icon
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)

                // Account info
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.formattedDisplayName)
                        .font(.headline)

                    Text(account.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Last sync
                    Text("Last sync: \(account.lastSyncFormatted)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Status
                connectionStatusBadge
            }

            Divider()

            // Permissions badges
            HStack(spacing: 12) {
                Label(
                    account.hasCalendarAccess ? "Calendar" : "No Calendar",
                    systemImage: account.hasCalendarAccess ? "calendar.badge.checkmark" : "calendar.badge.exclamationmark"
                )
                .font(.caption)
                .foregroundStyle(account.hasCalendarAccess ? .green : .orange)

                Label(
                    account.hasGmailAccess ? "Gmail" : "No Gmail",
                    systemImage: account.hasGmailAccess ? "envelope.badge.checkmark" : "envelope.badge.exclamationmark"
                )
                .font(.caption)
                .foregroundStyle(account.hasGmailAccess ? .green : .orange)

                Spacer()

                // Actions menu
                actionsMenu
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Connection Status Badge

    private var connectionStatusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(account.isConnected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            Text(account.isConnected ? "Connected" : "Disconnected")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(6)
    }

    // MARK: - Actions Menu

    private var actionsMenu: some View {
        Menu {
            Button {
                Task {
                    await viewModel.refreshAccountStatus(account)
                }
            } label: {
                Label("Refresh Status", systemImage: "arrow.clockwise")
            }

            if !viewModel.hasAllPermissions(account) {
                Button {
                    Task {
                        await viewModel.reAuthenticateAccount(account, context: modelContext)
                    }
                } label: {
                    Label("Re-authenticate", systemImage: "key.fill")
                }
            }

            Divider()

            Button(role: .destructive) {
                viewModel.disconnectAccount(account, context: modelContext)
            } label: {
                Label("Disconnect", systemImage: "xmark.circle")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
        }
        .menuStyle(.borderlessButton)
    }
}

// MARK: - Preview

#Preview {
    AccountsView()
        .modelContainer(for: [GoogleAccount.self], inMemory: true)
}
