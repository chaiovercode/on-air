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

    // MARK: - Services

    let settings = UserSettings()
    let calendarService = CalendarService()
    let countdownPlayer = CountdownPlayer()
    let statsService = StatsService()

    // MARK: - Private

    private var pollTimer: Timer?
    private var tickTimer: Timer?
    private var countdownScheduled = false
    private var lastRecordedEventId: String?

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
    }

    func stop() {
        pollTimer?.invalidate()
        tickTimer?.invalidate()
        countdownPlayer.stop()
    }

    // MARK: - Core logic

    func refreshEvents() {
        todayEvents = calendarService.fetchTodayEvents(
            disabledCalendarIds: settings.disabledCalendarIds
        )

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

        if remaining <= 300 && remaining > 0 {
            startTickTimer()
        }

        if remaining <= settings.leadTimeSeconds && remaining > 0 && !countdownScheduled {
            scheduleCountdown(for: next)
        }

        // Record attendance
        if remaining <= 0 {
            if let next = nextEvent, next.id != lastRecordedEventId && settings.trackStats {
                statsService.recordAttendance(next)
                lastRecordedEventId = next.id
            }
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

                if remaining <= 0 {
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

        guard let next = nextEvent else {
            return "● No meetings"
        }

        let remaining = Int(next.startDate.timeIntervalSinceNow)
        let truncatedTitle = String(next.title.prefix(25))

        if remaining <= 0 {
            return "● \(truncatedTitle) (now)"
        }

        let timeStr = TimeFormatter.format(seconds: remaining)
        if countdownActive {
            return "● \(truncatedTitle) in \(timeStr) 🔊"
        }
        return "● \(truncatedTitle) in \(timeStr)"
    }

    var isNextEventInProgress: Bool {
        guard let next = nextEvent else { return false }
        return next.startDate <= Date() && next.endDate > Date()
    }
}
