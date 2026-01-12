//
//  CalendarView.swift
//  orbit
//
//  Main calendar view with grid and event list
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    // MARK: - Environment & State

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CalendarEvent.startDate) private var events: [CalendarEvent]
    @State private var viewModel = CalendarViewModel()

    var body: some View {
        HSplitView {
            // Calendar grid
            calendarGrid
                .frame(minWidth: 500)

            // Events sidebar
            eventsSidebar
                .frame(minWidth: 250, idealWidth: 300)
        }
        .sheet(isPresented: $viewModel.showingAddEventSheet) {
            addEventSheet
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 16) {
            // Header with navigation
            calendarHeader

            // Weekday labels
            weekdayLabels

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(viewModel.daysInMonth(), id: \.self) { date in
                    if let date = date {
                        CalendarDayCell(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate),
                            isToday: Calendar.current.isDateInToday(date),
                            events: viewModel.events(for: date, from: events),
                            onSelect: { viewModel.selectedDate = date }
                        )
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Calendar Header

    private var calendarHeader: some View {
        HStack {
            Button(action: viewModel.previousMonth) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Spacer()

            Text(viewModel.monthYearString)
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Button(action: viewModel.nextMonth) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)

            Button("Today") {
                viewModel.goToToday()
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Weekday Labels

    private var weekdayLabels: some View {
        HStack(spacing: 8) {
            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Events Sidebar

    private var eventsSidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Events")
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.showingAddEventSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // Selected date
            Text(viewModel.selectedDate, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            // Events list
            let dayEvents = viewModel.events(for: viewModel.selectedDate, from: events)

            if dayEvents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("No events")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button("Add Event") {
                        viewModel.showingAddEventSheet = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(dayEvents) { event in
                            EventCard(event: event, viewModel: viewModel)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Add Event Sheet

    private var addEventSheet: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("New Event")
                    .font(.title2)
                    .fontWeight(.bold)

                // Title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.headline)

                    TextField("Event title", text: $viewModel.newEventTitle)
                        .textFieldStyle(.roundedBorder)
                }

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)

                    TextField("Description (optional)", text: $viewModel.newEventDescription, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)
                }

                // All-day toggle
                Toggle("All-day event", isOn: $viewModel.newEventIsAllDay)

                // Dates
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start")
                            .font(.headline)

                        DatePicker("", selection: $viewModel.newEventStartDate, displayedComponents: viewModel.newEventIsAllDay ? [.date] : [.date, .hourAndMinute])
                            .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("End")
                            .font(.headline)

                        DatePicker("", selection: $viewModel.newEventEndDate, displayedComponents: viewModel.newEventIsAllDay ? [.date] : [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                }

                // Location
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location")
                        .font(.headline)

                    TextField("Location (optional)", text: $viewModel.newEventLocation)
                        .textFieldStyle(.roundedBorder)
                }

                // Category
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category")
                        .font(.headline)

                    Picker("Category", selection: $viewModel.newEventCategory) {
                        ForEach(EventCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.systemImage)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Reminder
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reminder")
                        .font(.headline)

                    Picker("Reminder", selection: $viewModel.newEventReminder) {
                        Text("None").tag(nil as ReminderTime?)

                        ForEach(ReminderTime.allCases) { reminder in
                            Text(reminder.displayName).tag(reminder as ReminderTime?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                // Buttons
                HStack {
                    Button("Cancel") {
                        viewModel.showingAddEventSheet = false
                    }
                    .buttonStyle(.bordered)

                    Button("Add Event") {
                        viewModel.addEvent(context: modelContext)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(30)
        }
        .frame(width: 500, height: 600)
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let events: [CalendarEvent]
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(textColor)

                // Event indicators
                if !events.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(events.prefix(3)) { event in
                            Circle()
                                .fill(categoryColor(event.category))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isSelected {
            return .blue.opacity(0.2)
        } else {
            return Color(nsColor: .controlBackgroundColor)
        }
    }

    private var textColor: Color {
        isToday ? .blue : .primary
    }

    private var borderColor: Color {
        if isToday {
            return .blue
        } else if isSelected {
            return .blue.opacity(0.5)
        } else {
            return .clear
        }
    }

    private var borderWidth: CGFloat {
        isToday ? 2 : 1
    }

    private func categoryColor(_ category: EventCategory) -> Color {
        switch category.colorName {
        case "blue": return .blue
        case "orange": return .orange
        case "green": return .green
        case "purple": return .purple
        case "red": return .red
        case "pink": return .pink
        default: return .gray
        }
    }
}

// MARK: - Event Card

struct EventCard: View {
    let event: CalendarEvent
    @Bindable var viewModel: CalendarViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(categoryColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)

                if !event.isAllDay {
                    Text("\(event.startDate, style: .time) - \(event.endDate, style: .time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let location = event.location {
                    Label(location, systemImage: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                viewModel.deleteEvent(event, context: modelContext)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var categoryColor: Color {
        switch event.category.colorName {
        case "blue": return .blue
        case "orange": return .orange
        case "green": return .green
        case "purple": return .purple
        case "red": return .red
        case "pink": return .pink
        default: return .gray
        }
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: CalendarEvent.self, inMemory: true)
}
