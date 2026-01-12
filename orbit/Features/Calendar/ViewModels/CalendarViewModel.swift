//
//  CalendarViewModel.swift
//  orbit
//
//  ViewModel for calendar feature
//

import Foundation
import SwiftData
import Observation

/// ViewModel managing calendar events and state
@Observable
final class CalendarViewModel {
    // MARK: - Published State

    /// Currently displayed month
    var currentMonth: Date = Date()

    /// Selected date
    var selectedDate: Date = Date()

    /// Whether add event sheet is showing
    var showingAddEventSheet = false

    /// New event title
    var newEventTitle = ""

    /// New event description
    var newEventDescription = ""

    /// New event start date
    var newEventStartDate = Date()

    /// New event end date
    var newEventEndDate = Date().addingTimeInterval(3600) // +1 hour

    /// New event is all day
    var newEventIsAllDay = false

    /// New event location
    var newEventLocation = ""

    /// New event category
    var newEventCategory: EventCategory = .general

    /// New event reminder
    var newEventReminder: ReminderTime?

    /// Error message if any
    var errorMessage: String?

    // MARK: - Initialization

    init() {}

    // MARK: - Navigation

    /// Move to previous month
    func previousMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }

    /// Move to next month
    func nextMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }

    /// Move to today
    func goToToday() {
        currentMonth = Date()
        selectedDate = Date()
    }

    // MARK: - Event Management

    /// Adds a new event
    @MainActor
    func addEvent(context: ModelContext) {
        guard !newEventTitle.isEmpty else {
            errorMessage = "Please enter an event title"
            return
        }

        guard newEventEndDate > newEventStartDate else {
            errorMessage = "End date must be after start date"
            return
        }

        let event = CalendarEvent(
            title: newEventTitle,
            eventDescription: newEventDescription.isEmpty ? nil : newEventDescription,
            startDate: newEventStartDate,
            endDate: newEventEndDate,
            isAllDay: newEventIsAllDay,
            location: newEventLocation.isEmpty ? nil : newEventLocation,
            category: newEventCategory,
            reminderMinutes: newEventReminder?.rawValue
        )

        context.insert(event)

        do {
            try context.save()

            // Reset form
            resetEventForm()
            showingAddEventSheet = false
        } catch {
            errorMessage = "Failed to add event: \(error.localizedDescription)"
        }
    }

    /// Deletes an event
    @MainActor
    func deleteEvent(_ event: CalendarEvent, context: ModelContext) {
        context.delete(event)

        do {
            try context.save()
        } catch {
            errorMessage = "Failed to delete event: \(error.localizedDescription)"
        }
    }

    /// Resets the event form
    private func resetEventForm() {
        newEventTitle = ""
        newEventDescription = ""
        newEventStartDate = Date()
        newEventEndDate = Date().addingTimeInterval(3600)
        newEventIsAllDay = false
        newEventLocation = ""
        newEventCategory = .general
        newEventReminder = nil
    }

    // MARK: - Helpers

    /// Gets events for a specific date
    func events(for date: Date, from allEvents: [CalendarEvent]) -> [CalendarEvent] {
        allEvents.filter { event in
            Calendar.current.isDate(event.startDate, inSameDayAs: date)
        }
    }

    /// Gets days in current month
    func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: currentMonth)

        guard let firstDay = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingEmptyDays = Array(repeating: nil as Date?, count: firstWeekday - 1)

        let days = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }

        return leadingEmptyDays + days
    }

    /// Formatted month and year
    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
}
