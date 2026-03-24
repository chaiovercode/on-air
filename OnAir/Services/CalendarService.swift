import EventKit
import Foundation

final class CalendarService: ObservableObject {

    enum AuthorizationStatus {
        case notDetermined, authorized, denied
    }

    private let store = EKEventStore()
    @Published private(set) var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published private(set) var availableCalendars: [(id: String, title: String)] = []

    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(macOS 14.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            await MainActor.run {
                authorizationStatus = granted ? .authorized : .denied
                if granted { loadCalendars() }
            }
            return granted
        } catch {
            await MainActor.run { authorizationStatus = .denied }
            return false
        }
    }

    func fetchTodayEvents(disabledCalendarIds: Set<String>) -> [CalendarEvent] {
        let calendars = Calendar.current
        let startOfDay = calendars.startOfDay(for: Date())
        guard let endOfDay = calendars.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        return ekEvents
            .map { mapEvent($0) }
            .filter { $0.shouldShow }
            .filter { !disabledCalendarIds.contains($0.calendarId) }
            .sorted()
    }

    func fetchEvents(from startDate: Date, to endDate: Date, disabledCalendarIds: Set<String>) -> [CalendarEvent] {
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        return ekEvents
            .map { mapEvent($0) }
            .filter { $0.shouldShow }
            .filter { !disabledCalendarIds.contains($0.calendarId) }
            .sorted()
    }

    func startObserving(onChange: @escaping () -> Void) {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { _ in onChange() }

        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { _ in onChange() }
    }

    private func loadCalendars() {
        availableCalendars = store.calendars(for: .event)
            .map { (id: $0.calendarIdentifier, title: $0.title) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func fetchAllDayEvents(from startDate: Date, to endDate: Date, disabledCalendarIds: Set<String>) -> [CalendarEvent] {
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return store.events(matching: predicate)
            .map { mapEvent($0) }
            .filter { $0.isAllDay && $0.status != .cancelled && $0.participationStatus != .declined }
            .filter { !disabledCalendarIds.contains($0.calendarId) }
    }

    private func mapEvent(_ ekEvent: EKEvent) -> CalendarEvent {
        CalendarEvent(
            id: ekEvent.eventIdentifier,
            title: ekEvent.title ?? "Untitled",
            startDate: ekEvent.startDate,
            endDate: ekEvent.endDate,
            isAllDay: ekEvent.isAllDay,
            location: ekEvent.location,
            notes: ekEvent.notes,
            status: mapStatus(ekEvent.status),
            participationStatus: mapParticipation(ekEvent),
            calendarTitle: ekEvent.calendar.title,
            calendarId: ekEvent.calendar.calendarIdentifier,
            calendarColorHex: colorHex(from: ekEvent.calendar)
        )
    }

    private func colorHex(from calendar: EKCalendar) -> String {
        guard let converted = calendar.cgColor.converted(
            to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil
        ), let c = converted.components, c.count >= 3 else {
            return "#808080"
        }
        return String(format: "#%02X%02X%02X", Int(c[0] * 255), Int(c[1] * 255), Int(c[2] * 255))
    }

    private func mapStatus(_ status: EKEventStatus) -> CalendarEvent.Status {
        switch status {
        case .confirmed: return .confirmed
        case .tentative: return .tentative
        case .canceled: return .cancelled
        @unknown default: return .confirmed
        }
    }

    private func mapParticipation(_ event: EKEvent) -> CalendarEvent.ParticipationStatus {
        guard let me = event.attendees?.first(where: { $0.isCurrentUser }) else {
            return .accepted
        }
        switch me.participantStatus {
        case .accepted: return .accepted
        case .declined: return .declined
        case .tentative: return .tentative
        case .pending: return .pending
        @unknown default: return .pending
        }
    }
}
