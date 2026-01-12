//
//  SpamFilterViewModel.swift
//  orbit
//
//  ViewModel for spam filter management
//

import Foundation
import SwiftData
import Observation

/// ViewModel managing spam filter rules
@Observable
final class SpamFilterViewModel {
    // MARK: - Published State

    /// Whether add rule sheet is showing
    var showingAddRuleSheet = false

    /// New rule name
    var newRuleName = ""

    /// New rule filter type
    var newRuleFilterType: FilterType = .keyword

    /// New rule filter value
    var newRuleFilterValue = ""

    /// Error message if any
    var errorMessage: String?

    // MARK: - Initialization

    init() {}

    // MARK: - Rule Management

    /// Adds a new spam filter rule
    @MainActor
    func addRule(context: ModelContext) {
        guard !newRuleName.isEmpty else {
            errorMessage = "Please enter a rule name"
            return
        }

        guard !newRuleFilterValue.isEmpty else {
            errorMessage = "Please enter a filter value"
            return
        }

        let rule = SpamFilterRule(
            name: newRuleName,
            filterType: newRuleFilterType,
            filterValue: newRuleFilterValue,
            isEnabled: true
        )

        context.insert(rule)

        do {
            try context.save()

            // Reset form
            newRuleName = ""
            newRuleFilterValue = ""
            showingAddRuleSheet = false
        } catch {
            errorMessage = "Failed to add rule: \(error.localizedDescription)"
        }
    }

    /// Toggles a rule's enabled state
    @MainActor
    func toggleRule(_ rule: SpamFilterRule, context: ModelContext) {
        rule.isEnabled.toggle()

        do {
            try context.save()
        } catch {
            errorMessage = "Failed to toggle rule: \(error.localizedDescription)"
        }
    }

    /// Deletes a spam filter rule
    @MainActor
    func deleteRule(_ rule: SpamFilterRule, context: ModelContext) {
        context.delete(rule)

        do {
            try context.save()
        } catch {
            errorMessage = "Failed to delete rule: \(error.localizedDescription)"
        }
    }

    // MARK: - Statistics

    /// Calculates total blocked emails
    func totalBlockedEmails(from rules: [SpamFilterRule]) -> Int {
        rules.reduce(0) { $0 + $1.blockedCount }
    }

    /// Calculates active rules count
    func activeRulesCount(from rules: [SpamFilterRule]) -> Int {
        rules.filter { $0.isEnabled }.count
    }
}
