import SwiftUI

struct AgendaView: View {

    @ObservedObject var appState: AppState
    let selectedDate: Date?
    var onNewEvent: (() -> Void)? = nil

    private var accentRed: Color { Color(hex: appState.settings.accentColorHex) }
    private let calendar = Calendar.current

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(agendaDays, id: \.date) { day in
                // Skip empty days if hidden (but always show today)
                if day.isEmpty && appState.settings.hideEmptyDays && !day.isToday {
                    EmptyView()
                } else {
                // Section header
                daySectionHeader(day)

                // All-day events
                if !day.allDayEvents.isEmpty {
                    AllDayRow(events: day.allDayEvents)
                        .padding(.bottom, 4)
                }

                if day.events.isEmpty && day.allDayEvents.isEmpty {
                    Button {
                        appState.settings.hideEmptyDays = true
                    } label: {
                        Text("Hide empty days")
                            .font(.system(size: 11))
                            .foregroundStyle(.quaternary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                } else {
                    // Timed events with now indicator
                    let pastEvents = day.isToday ? day.events.filter { $0.endDate <= Date() && !isInProgress($0) } : []
                    let currentAndFuture = day.isToday ? day.events.filter { $0.endDate > Date() || isInProgress($0) } : day.events

                    // Past events
                    ForEach(pastEvents) { event in
                        MeetingRowView(
                            event: event,
                            isNext: false,
                            isInProgress: false,
                            isPast: true,
                            accentRed: accentRed,
                            use24HourTime: appState.settings.use24HourTime,
                            hasConflict: appState.hasConflict(event)
                        )
                    }

                    // Now indicator (only for today, between past and current/future)
                    if day.isToday && !pastEvents.isEmpty && !currentAndFuture.isEmpty {
                        nowIndicator
                    }

                    // Current + future events
                    ForEach(currentAndFuture) { event in
                        MeetingRowView(
                            event: event,
                            isNext: event.id == appState.nextEvent?.id && !isInProgress(event),
                            isInProgress: isInProgress(event),
                            isPast: false,
                            accentRed: accentRed,
                            use24HourTime: appState.settings.use24HourTime,
                            hasConflict: appState.hasConflict(event)
                        )
                    }
                }
                } // end if/else empty check
            }
        }
    }

    // MARK: - Now Indicator

    private var nowIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(accentRed)
                .frame(width: 7, height: 7)

            Rectangle()
                .fill(accentRed)
                .frame(height: 1.5)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Section Header

    private func daySectionHeader(_ day: AgendaDay) -> some View {
        HStack {
            if day.isToday {
                Button {
                    NotificationCenter.default.post(name: .toggleTimeline, object: nil)
                } label: {
                    HStack(spacing: 4) {
                        Text(day.headerText)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(accentRed)
                            .tracking(1.2)
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(accentRed.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(day.headerText)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1.2)
            }

            Spacer()

            if day.isToday, let onNewEvent {
                Button {
                    onNewEvent()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("⌘N")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, day.isFirst ? 4 : 14)
        .padding(.bottom, 6)
    }

    // MARK: - Data

    private struct AgendaDay: Identifiable {
        let date: Date
        let events: [CalendarEvent]
        let allDayEvents: [CalendarEvent]
        let headerText: String
        let isFirst: Bool
        let isToday: Bool

        var isEmpty: Bool { events.isEmpty && allDayEvents.isEmpty }
        var id: Date { date }
    }

    private var agendaDays: [AgendaDay] {
        let today = calendar.startOfDay(for: Date())
        let effectiveDate = selectedDate ?? today

        var days: [AgendaDay] = []

        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: effectiveDate) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { continue }
            let isToday = calendar.isDateInToday(date)

            let events: [CalendarEvent]
            if isToday {
                events = appState.todayEvents.filter { $0.endDate > Date() || appState.settings.showPastMeetings }
            } else {
                events = appState.calendarService.fetchEvents(
                    from: startOfDay,
                    to: endOfDay,
                    disabledCalendarIds: appState.settings.disabledCalendarIds
                )
            }

            let allDayEvents = appState.calendarService.fetchAllDayEvents(
                from: startOfDay,
                to: endOfDay,
                disabledCalendarIds: appState.settings.disabledCalendarIds
            )

            let headerText = dayHeaderText(for: date)
            days.append(AgendaDay(
                date: date,
                events: events,
                allDayEvents: allDayEvents,
                headerText: headerText,
                isFirst: offset == 0,
                isToday: isToday
            ))
        }

        return days
    }

    private func dayHeaderText(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "TODAY"
        } else if calendar.isDateInTomorrow(date) {
            return "TOMORROW"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, d MMM"
            return formatter.string(from: date).uppercased()
        }
    }

    private func isInProgress(_ event: CalendarEvent) -> Bool {
        event.startDate <= Date() && event.endDate > Date()
    }
}

// MARK: - All-Day Events Row

private struct AllDayRow: View {
    let events: [CalendarEvent]
    @State private var expanded = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 10)

                    // Calendar color dots
                    HStack(spacing: 3) {
                        ForEach(uniqueColors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 7, height: 7)
                        }
                    }

                    Text("\(events.count) all-day")
                        .font(.system(size: 12, weight: .medium))

                    if !expanded {
                        Text(events.map(\.title).joined(separator: ", "))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if expanded {
                    ForEach(events) { event in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: event.calendarColorHex))
                                .frame(width: 5, height: 5)
                            Text(event.title)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 18)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    private var uniqueColors: [String] {
        var seen = Set<String>()
        return events.compactMap { event in
            if seen.contains(event.calendarColorHex) { return nil }
            seen.insert(event.calendarColorHex)
            return event.calendarColorHex
        }
    }
}
