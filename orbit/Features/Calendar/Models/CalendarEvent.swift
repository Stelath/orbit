//
//  CalendarEvent.swift
//  orbit
//
//  Calendar event data model
//

import Foundation
import SwiftData

/// Represents a calendar event
@Model
final class CalendarEvent {
    /// Unique identifier
    var id: UUID

    /// Event title
    var title: String

    /// Event description
    var eventDescription: String?

    /// Event start date and time
    var startDate: Date

    /// Event end date and time
    var endDate: Date

    /// Whether this is an all-day event
    var isAllDay: Bool

    /// Event location
    var location: String?

    /// Event category
    var category: EventCategory

    /// Reminder time before event
    var reminderMinutes: Int?

    /// Date event was created
    var dateCreated: Date

    /// Initializer
    init(
        id: UUID = UUID(),
        title: String,
        eventDescription: String? = nil,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        category: EventCategory = .general,
        reminderMinutes: Int? = nil,
        dateCreated: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.eventDescription = eventDescription
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.category = category
        self.reminderMinutes = reminderMinutes
        self.dateCreated = dateCreated
    }
}

/// Event category enumeration
enum EventCategory: String, Codable, CaseIterable, Identifiable {
    case general = "General"
    case work = "Work"
    case personal = "Personal"
    case meeting = "Meeting"
    case deadline = "Deadline"
    case birthday = "Birthday"

    var id: String { rawValue }

    /// System image for each category
    var systemImage: String {
        switch self {
        case .general:
            return "calendar"
        case .work:
            return "briefcase.fill"
        case .personal:
            return "person.fill"
        case .meeting:
            return "person.2.fill"
        case .deadline:
            return "clock.fill"
        case .birthday:
            return "gift.fill"
        }
    }

    /// Color for each category
    var colorName: String {
        switch self {
        case .general:
            return "blue"
        case .work:
            return "orange"
        case .personal:
            return "green"
        case .meeting:
            return "purple"
        case .deadline:
            return "red"
        case .birthday:
            return "pink"
        }
    }
}

/// Reminder time options
enum ReminderTime: Int, CaseIterable, Identifiable {
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case oneDay = 1440

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .fifteenMinutes:
            return "15 minutes before"
        case .thirtyMinutes:
            return "30 minutes before"
        case .oneHour:
            return "1 hour before"
        case .oneDay:
            return "1 day before"
        }
    }
}
