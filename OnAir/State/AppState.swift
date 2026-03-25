import Combine
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published state

    @Published var todayEvents: [CalendarEvent] = []
    @Published var nextEvent: CalendarEvent? = nil
    @Published var secondsUntilNext: Int = 0
    @Published var countdownActive: Bool = false
    @Published var calendarAccessDenied: Bool = false
    @Published var soundWarning: Bool = false
    @Published var wrapUpAlert: Bool = false
    @Published var minuteTick: Int = 0  // Increments every minute to refresh time-dependent views
    var dismissedFocusGaps: Set<String> = []

    // MARK: - Services

    let settings = UserSettings()
    let calendarService = CalendarService()
    let countdownPlayer = CountdownPlayer()
    let statsService = StatsService()
    let focusService = FocusService()

    // MARK: - Private

    private var pollTimer: Timer?
    private var tickTimer: Timer?
    private var minuteTimer: Timer?
    private var countdownScheduled = false
    private var settingsSink: AnyCancellable?
    private var calendarSink: AnyCancellable?
    private var focusSink: AnyCancellable?

    init() {
        // Forward settings changes so views observing AppState re-render
        settingsSink = settings.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        calendarSink = calendarService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        focusSink = focusService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: - Lifecycle

    func start() async {
        let granted = await calendarService.requestAccess()
        calendarAccessDenied = !granted

        guard granted else { return }

        refreshEvents()
        calendarService.startObserving { [weak self] in
            self?.refreshEvents()
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshEvents() }
        }

        // Tick every minute to refresh time-dependent displays (e.g. "Xm left")
        minuteTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.minuteTick += 1 }
        }
    }

    func stop() {
        pollTimer?.invalidate()
        tickTimer?.invalidate()
        minuteTimer?.invalidate()
        countdownPlayer.stop()
    }

    // MARK: - Core logic

    func refreshEvents() {
        todayEvents = calendarService.fetchTodayEvents(
            disabledCalendarIds: settings.disabledCalendarIds
        )

        // Record attendance for all ended meetings today
        if settings.trackStats {
            let now = Date()
            for event in todayEvents where event.endDate <= now {
                let names = calendarService.attendeeNames(eventId: event.id)
                statsService.recordAttendance(event, attendees: names)
                statsService.backfillAttendees(eventId: event.id, names: names)
            }
        }

        let now = Date()
        nextEvent = todayEvents.first { $0.endDate > now }
        updateCountdown()
    }

    private func updateCountdown() {
        guard let next = nextEvent else {
            secondsUntilNext = 0
            stopCountdown()
            return
        }

        let remaining = Int(next.startDate.timeIntervalSinceNow)
        secondsUntilNext = max(remaining, 0)

        if remaining <= 300 {
            startTickTimer()
        }

        if remaining <= settings.leadTimeSeconds && remaining > 0 && !countdownScheduled {
            scheduleCountdown(for: next)
        }

        if remaining <= 0 {
            countdownActive = false
            countdownScheduled = false
        }
    }

    private func startTickTimer() {
        guard tickTimer == nil else { return }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let next = self.nextEvent else { return }
                let remaining = Int(next.startDate.timeIntervalSinceNow)
                self.secondsUntilNext = max(remaining, 0)

                // Check if countdown sound should start (may have been missed by 60s poll)
                if remaining <= self.settings.leadTimeSeconds && remaining > 0 && !self.countdownScheduled {
                    self.scheduleCountdown(for: next)
                }

                // Wrap-up alert: check if current meeting is ending soon
                // Skip if there's a back-to-back meeting (next starts within 5 min of current ending)
                if remaining <= 0, self.settings.wrapUpMinutes > 0 {
                    let secsUntilEnd = Int(next.endDate.timeIntervalSinceNow)
                    let threshold = self.settings.wrapUpMinutes * 60
                    let hasBackToBack = self.todayEvents.contains { event in
                        event.id != next.id &&
                        event.startDate >= next.startDate &&
                        abs(event.startDate.timeIntervalSince(next.endDate)) < 300
                    }
                    self.wrapUpAlert = secsUntilEnd > 0 && secsUntilEnd <= threshold && !hasBackToBack
                } else {
                    self.wrapUpAlert = false
                }

                // Meeting ended — stop timer and move to next event
                if remaining <= 0 && next.endDate <= Date() {
                    self.stopCountdown()
                    self.refreshEvents()
                }
            }
        }
    }

    private func scheduleCountdown(for event: CalendarEvent) {
        let loaded = countdownPlayer.loadSound(
            customPath: settings.customSoundPath,
            volume: Float(settings.volume)
        )
        soundWarning = !loaded

        if loaded {
            countdownPlayer.schedulePlayback(
                meetingStartDate: event.startDate,
                leadTimeSeconds: settings.leadTimeSeconds
            )
            countdownActive = true
            countdownScheduled = true
        }
    }

    private func stopCountdown() {
        tickTimer?.invalidate()
        tickTimer = nil
        countdownPlayer.stop()
        countdownActive = false
        countdownScheduled = false
    }

    // MARK: - Menu bar text

    var menuBarText: String {
        if calendarAccessDenied {
            return "⚠ Calendar access needed"
        }

        // Focus timer in menu bar — show minutes only, seconds in last minute
        let focusPart: String? = {
            guard focusService.isRunning else { return nil }
            let secs = focusService.secondsRemaining
            let time: String
            if secs >= 60 {
                time = "\((secs + 59) / 60)m" // round up to nearest minute
            } else {
                time = "\(secs)s"
            }
            return focusService.isPaused ? "⏸ \(time)" : "◉ \(time)"
        }()

        guard let next = nextEvent else {
            if let fp = focusPart {
                return "● \(fp)"
            }
            return nextFutureMeetingText
        }

        let remaining = Int(next.startDate.timeIntervalSinceNow)
        let truncatedTitle = String(next.title.prefix(18))

        // Check for upcoming conflict while in a meeting
        let conflictPart: String? = {
            guard remaining <= 0, let upcoming = upcomingEvent else { return nil }
            let upIn = Int(upcoming.startDate.timeIntervalSinceNow)
            guard upIn > 0 && upIn <= 900 else { return nil } // show within 15 min
            return "\(String(upcoming.title.prefix(12))) in \(TimeFormatter.format(seconds: upIn)) ⚠"
        }()

        if remaining <= 0 {
            // Show time until meeting ends when wrap-up is active
            let wrapPart: String? = {
                guard wrapUpAlert else { return nil }
                let secsLeft = Int(next.endDate.timeIntervalSinceNow)
                guard secsLeft > 0 else { return nil }
                let mins = (secsLeft + 59) / 60 // round up
                return "ends \(mins)m"
            }()

            var text = "● \(truncatedTitle)"
            if let wp = wrapPart { text += " (\(wp))" }
            if let cp = conflictPart { text += " · \(cp)" }
            else if let fp = focusPart { text += " · \(fp)" }
            return text
        }

        let timeStr = TimeFormatter.format(seconds: remaining)
        if let fp = focusPart {
            return "● \(truncatedTitle) in \(timeStr) · \(fp)"
        }
        if countdownActive {
            return "● \(truncatedTitle) in \(timeStr) ♪"
        }
        return "● \(truncatedTitle) in \(timeStr)"
    }

    private var nextFutureMeetingText: String {
        // Look ahead 7 days for the next event
        let cal = Calendar.current
        let now = Date()
        let startOfTomorrow = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now) ?? now)
        guard let endDate = cal.date(byAdding: .day, value: 7, to: now) else {
            return "● All clear"
        }

        let futureEvents = calendarService.fetchEvents(
            from: startOfTomorrow,
            to: endDate,
            disabledCalendarIds: settings.disabledCalendarIds
        )

        guard let nextFuture = futureEvents.first else {
            return "● All clear"
        }

        let title = String(nextFuture.title.prefix(20))
        let dayText: String
        if cal.isDateInTomorrow(nextFuture.startDate) {
            dayText = "Tomorrow"
        } else {
            let f = DateFormatter()
            f.dateFormat = "EEE"
            dayText = f.string(from: nextFuture.startDate)
        }
        let timeF = DateFormatter()
        timeF.dateFormat = "h:mma"
        let time = timeF.string(from: nextFuture.startDate).lowercased().replacingOccurrences(of: "am", with: "a").replacingOccurrences(of: "pm", with: "p")

        return "● \(title) · \(dayText) \(time)"
    }

    var isNextEventInProgress: Bool {
        guard let next = nextEvent else { return false }
        return next.startDate <= Date() && next.endDate > Date()
    }

    /// The event after `nextEvent` that's still upcoming (for conflict/overlap display)
    var upcomingEvent: CalendarEvent? {
        let now = Date()
        guard let current = nextEvent else { return nil }
        return todayEvents.first { $0.id != current.id && $0.startDate > now && $0.endDate > now }
    }

    /// Events that overlap with a given event
    func overlappingEvents(for event: CalendarEvent) -> [CalendarEvent] {
        todayEvents.filter { $0.overlaps(with: event) }
    }

    /// Whether an event has conflicts
    func hasConflict(_ event: CalendarEvent) -> Bool {
        todayEvents.contains { $0.overlaps(with: event) }
    }
}
