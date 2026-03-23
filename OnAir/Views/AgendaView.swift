import SwiftUI

struct AgendaView: View {

    @ObservedObject var appState: AppState
    let selectedDate: Date?

    private let accentRed = Color(red: 0.9, green: 0.25, blue: 0.2)
    private let calendar = Calendar.current

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(agendaDays, id: \.date) { day in
                // Section header
                daySectionHeader(day)

                if day.events.isEmpty {
                    HStack {
                        Text("Nothing scheduled")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                } else {
                    ForEach(day.events) { event in
                        MeetingRowView(
                            event: event,
                            isNext: event.id == appState.nextEvent?.id && !isInProgress(event),
                            isInProgress: isInProgress(event),
                            isPast: event.endDate <= Date(),
                            accentRed: accentRed
                        )
                    }
                }
            }
        }
    }

    // MARK: - Section Header

    private func daySectionHeader(_ day: AgendaDay) -> some View {
        HStack {
            Text(day.headerText)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accentRed)
                .tracking(1.5)

            Spacer()
        }
        .padding(.top, day.isFirst ? 4 : 14)
        .padding(.bottom, 6)
    }

    // MARK: - Data

    private struct AgendaDay: Identifiable {
        let date: Date
        let events: [CalendarEvent]
        let headerText: String
        let isFirst: Bool

        var id: Date { date }
    }

    private var agendaDays: [AgendaDay] {
        let today = calendar.startOfDay(for: Date())
        let effectiveDate = selectedDate ?? today

        // Show 7 days starting from the selected/today date
        var days: [AgendaDay] = []

        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: effectiveDate) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { continue }

            let events: [CalendarEvent]
            if calendar.isDateInToday(date) {
                // Use already-loaded today events
                events = appState.todayEvents.filter { $0.endDate > Date() || appState.settings.showPastMeetings }
            } else {
                events = appState.calendarService.fetchEvents(
                    from: startOfDay,
                    to: endOfDay,
                    disabledCalendarIds: appState.settings.disabledCalendarIds
                )
            }

            let headerText = dayHeaderText(for: date)
            days.append(AgendaDay(date: date, events: events, headerText: headerText, isFirst: offset == 0))
        }

        return days
    }

    private func dayHeaderText(for date: Date) -> String {
        let today = calendar.startOfDay(for: Date())

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
