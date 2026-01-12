//
//  SpamFilterView.swift
//  orbit
//
//  Spam filtering management view
//

import SwiftUI
import SwiftData

struct SpamFilterView: View {
    // MARK: - Environment & State

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpamFilterRule.dateCreated, order: .reverse) private var rules: [SpamFilterRule]
    @State private var viewModel = SpamFilterViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Statistics
                statisticsSection

                Divider()

                // Rules list or empty state
                if rules.isEmpty {
                    emptyRulesView
                } else {
                    rulesListSection
                }
            }
            .padding()
        }
        .sheet(isPresented: $viewModel.showingAddRuleSheet) {
            addRuleSheet
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Spam Filtering")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Create rules to automatically filter spam emails")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.showingAddRuleSheet = true
            } label: {
                Label("Add Rule", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Total Rules",
                value: "\(rules.count)",
                systemImage: "list.bullet",
                color: .blue
            )

            StatCard(
                title: "Active Rules",
                value: "\(viewModel.activeRulesCount(from: rules))",
                systemImage: "checkmark.circle.fill",
                color: .green
            )

            StatCard(
                title: "Emails Blocked",
                value: "\(viewModel.totalBlockedEmails(from: rules))",
                systemImage: "shield.fill",
                color: .orange
            )
        }
    }

    // MARK: - Empty State

    private var emptyRulesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.slash.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Spam Filter Rules")
                .font(.headline)

            Text("Create rules to start filtering spam")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                viewModel.showingAddRuleSheet = true
            } label: {
                Label("Create Your First Rule", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Rules List

    private var rulesListSection: some View {
        LazyVStack(spacing: 16) {
            ForEach(rules) { rule in
                FilterRuleCard(rule: rule, viewModel: viewModel)
            }
        }
    }

    // MARK: - Add Rule Sheet

    private var addRuleSheet: some View {
        VStack(spacing: 20) {
            Text("Add Spam Filter Rule")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Rule Name")
                    .font(.headline)

                TextField("e.g., Block marketing emails", text: $viewModel.newRuleName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Filter Type")
                    .font(.headline)

                Picker("Filter Type", selection: $viewModel.newRuleFilterType) {
                    ForEach(FilterType.allCases) { type in
                        Label(type.rawValue, systemImage: type.systemImage)
                            .tag(type)
                    }
                }
                .pickerStyle(.menu)

                Text(viewModel.newRuleFilterType.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Filter Value")
                    .font(.headline)

                TextField(placeholderText, text: $viewModel.newRuleFilterValue)
                    .textFieldStyle(.roundedBorder)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    viewModel.showingAddRuleSheet = false
                    viewModel.newRuleName = ""
                    viewModel.newRuleFilterValue = ""
                }
                .buttonStyle(.bordered)

                Button("Add Rule") {
                    viewModel.addRule(context: modelContext)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        .frame(width: 450)
    }

    private var placeholderText: String {
        switch viewModel.newRuleFilterType {
        case .keyword:
            return "e.g., unsubscribe, promotion"
        case .sender:
            return "e.g., spam@example.com"
        case .domain:
            return "e.g., spammer.com"
        case .aiPowered:
            return "AI will automatically detect patterns"
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Filter Rule Card

struct FilterRuleCard: View {
    let rule: SpamFilterRule
    @Bindable var viewModel: SpamFilterViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 16) {
            // Filter type icon
            Image(systemName: rule.filterType.systemImage)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())

            // Rule info
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.name)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label(rule.filterType.rawValue, systemImage: rule.filterType.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(rule.filterValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("\(rule.blockedCount) emails blocked")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in viewModel.toggleRule(rule, context: modelContext) }
            ))
            .labelsHidden()

            // Delete button
            Button {
                viewModel.deleteRule(rule, context: modelContext)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(rule.isEnabled ? 1.0 : 0.5)
    }
}

#Preview {
    SpamFilterView()
        .modelContainer(for: SpamFilterRule.self, inMemory: true)
}
