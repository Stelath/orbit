//
//  SpamFilterRule.swift
//  orbit
//
//  Spam filter rule data model
//

import Foundation
import SwiftData

/// Represents a spam filtering rule
@Model
final class SpamFilterRule {
    /// Unique identifier
    var id: UUID

    /// Rule name
    var name: String

    /// Filter type
    var filterType: FilterType

    /// Filter value (keyword, sender, domain, etc.)
    var filterValue: String

    /// Whether the rule is enabled
    var isEnabled: Bool

    /// Date rule was created
    var dateCreated: Date

    /// Number of emails blocked by this rule
    var blockedCount: Int

    /// Initializer
    init(
        id: UUID = UUID(),
        name: String,
        filterType: FilterType,
        filterValue: String,
        isEnabled: Bool = true,
        dateCreated: Date = Date(),
        blockedCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.filterType = filterType
        self.filterValue = filterValue
        self.isEnabled = isEnabled
        self.dateCreated = dateCreated
        self.blockedCount = blockedCount
    }
}

/// Filter type enumeration
enum FilterType: String, Codable, CaseIterable, Identifiable {
    case keyword = "Keyword"
    case sender = "Sender"
    case domain = "Domain"
    case aiPowered = "AI-Powered"

    var id: String { rawValue }

    /// System image for each filter type
    var systemImage: String {
        switch self {
        case .keyword:
            return "text.magnifyingglass"
        case .sender:
            return "person.fill"
        case .domain:
            return "globe"
        case .aiPowered:
            return "sparkles"
        }
    }

    /// Description of the filter type
    var description: String {
        switch self {
        case .keyword:
            return "Block emails containing specific keywords"
        case .sender:
            return "Block emails from specific senders"
        case .domain:
            return "Block emails from specific domains"
        case .aiPowered:
            return "Use AI to intelligently detect spam"
        }
    }
}
