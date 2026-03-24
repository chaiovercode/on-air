import Combine
import Foundation

@MainActor
final class FocusService: ObservableObject {

    // MARK: - Active session state

    @Published var isRunning = false
    @Published var isPaused = false
    @Published var secondsRemaining: Int = 0
    @Published var totalSeconds: Int = 0
    @Published var sessionLabel: String = "Deep Work"

    // MARK: - History

    @Published private(set) var sessions: [FocusSession] = []

    private var timer: Timer?
    private var sessionStart: Date?
    private let storageKey = "focusSessions"

    init() {
        loadSessions()
    }

    // MARK: - Timer controls

    func start(duration: Int, label: String) {
        sessionLabel = label
        totalSeconds = duration
        secondsRemaining = duration
        isRunning = true
        isPaused = false
        sessionStart = Date()
        startTimer()
    }

    func pause() {
        isPaused = true
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        isPaused = false
        startTimer()
    }

    func stop() {
        let actual = totalSeconds - secondsRemaining
        if actual > 30 { // only record if they focused for at least 30s
            let session = FocusSession(
                label: sessionLabel,
                duration: TimeInterval(totalSeconds),
                actualDuration: TimeInterval(actual),
                completed: false
            )
            sessions.insert(session, at: 0)
            saveSessions()
        }
        reset()
    }

    // MARK: - Suggestion

    func suggestedDuration(nextEventIn seconds: Int?) -> Int {
        guard let seconds, seconds > 0 else {
            return 25 * 60 // default 25 min pomodoro
        }
        let available = seconds - 5 * 60 // 5 min buffer before meeting
        let capped = min(available, 60 * 60) // max 60 min
        // Round down to nearest 5 min
        let rounded = (capped / 300) * 300
        return max(rounded, 5 * 60) // at least 5 min
    }

    // MARK: - Stats

    var todaySessions: [FocusSession] {
        let cal = Calendar.current
        return sessions.filter { cal.isDateInToday($0.date) }
    }

    var todayFocusMinutes: Int {
        Int(todaySessions.reduce(0) { $0 + $1.actualDuration } / 60)
    }

    var weekFocusMinutes: Int {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return Int(sessions.filter { $0.date > weekAgo }.reduce(0) { $0 + $1.actualDuration } / 60)
    }

    var totalSessions: Int { sessions.count }

    var completionRate: Double {
        guard !sessions.isEmpty else { return 0 }
        return Double(sessions.filter(\.completed).count) / Double(sessions.count)
    }

    // MARK: - Private

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRunning, !self.isPaused else { return }
                self.secondsRemaining -= 1
                if self.secondsRemaining <= 0 {
                    self.completeSession()
                }
            }
        }
    }

    private func completeSession() {
        let session = FocusSession(
            label: sessionLabel,
            duration: TimeInterval(totalSeconds),
            actualDuration: TimeInterval(totalSeconds),
            completed: true
        )
        sessions.insert(session, at: 0)
        saveSessions()
        reset()
    }

    private func reset() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        secondsRemaining = 0
        totalSeconds = 0
        sessionStart = nil
    }

    // MARK: - Persistence

    private func saveSessions() {
        // Keep last 500 sessions
        let toSave = Array(sessions.prefix(500))
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FocusSession].self, from: data) else { return }
        sessions = decoded
    }

    func clearAll() {
        sessions = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
