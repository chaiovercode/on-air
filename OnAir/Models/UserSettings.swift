import Foundation

final class UserSettings: ObservableObject {

    enum LeadTimePreset: Int, CaseIterable {
        case thirtySeconds = 30
        case fortyFiveSeconds = 45
        case oneMinute = 60
        case twoMinutes = 120
        case fiveMinutes = 300

        var seconds: Int { rawValue }

        var displayName: String {
            switch self {
            case .thirtySeconds: return "30 seconds"
            case .fortyFiveSeconds: return "45 seconds"
            case .oneMinute: return "1 minute"
            case .twoMinutes: return "2 minutes"
            case .fiveMinutes: return "5 minutes"
            }
        }
    }

    static let allKeys = [
        "leadTimeSeconds", "volume", "showPastMeetings",
        "launchAtLogin", "customSoundPath", "disabledCalendarIds", "trackStats"
    ]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.leadTimeSeconds = defaults.object(forKey: "leadTimeSeconds") as? Int ?? 45
        self.volume = defaults.object(forKey: "volume") as? Double ?? 0.75
        self.countdownSoundEnabled = defaults.object(forKey: "countdownSoundEnabled") as? Bool ?? false
        self.showPastMeetings = defaults.bool(forKey: "showPastMeetings")
        self.hideEmptyDays = defaults.bool(forKey: "hideEmptyDays")
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.trackStats = defaults.object(forKey: "trackStats") as? Bool ?? true
        self.customSoundPath = defaults.string(forKey: "customSoundPath")
        self.accentColorHex = defaults.string(forKey: "accentColorHex") ?? "#E6402E"
        self.use24HourTime = defaults.bool(forKey: "use24HourTime")
        self.showYearProgress = defaults.object(forKey: "showYearProgress") as? Bool ?? true
        self.showCalendarHeatmap = defaults.object(forKey: "showCalendarHeatmap") as? Bool ?? true
        self.wrapUpMinutes = defaults.object(forKey: "wrapUpMinutes") as? Int ?? 2
        self.focusCalendarId = defaults.string(forKey: "focusCalendarId")
        self.showCommute = defaults.bool(forKey: "showCommute")
        self.morningCommuteHour = defaults.object(forKey: "morningCommuteHour") as? Int ?? 8
        self.morningCommuteMinute = defaults.object(forKey: "morningCommuteMinute") as? Int ?? 30
        self.eveningCommuteHour = defaults.object(forKey: "eveningCommuteHour") as? Int ?? 18
        self.eveningCommuteMinute = defaults.object(forKey: "eveningCommuteMinute") as? Int ?? 0
        self.commuteDurationMinutes = defaults.object(forKey: "commuteDurationMinutes") as? Int ?? 30
        if let data = defaults.data(forKey: "commuteDays"),
           let days = try? JSONDecoder().decode(Set<Int>.self, from: data) {
            self._commuteDays = days
        }
        self.bookingEnabled = defaults.bool(forKey: "bookingEnabled")
        self.bookingName = defaults.string(forKey: "bookingName") ?? ""
        self.bookingStartHour = defaults.object(forKey: "bookingStartHour") as? Int ?? 9
        self.bookingEndHour = defaults.object(forKey: "bookingEndHour") as? Int ?? 17
        self.bookingSlotMinutes = defaults.object(forKey: "bookingSlotMinutes") as? Int ?? 30
        self.bookingBufferMinutes = defaults.object(forKey: "bookingBufferMinutes") as? Int ?? 10
        self.bookingDaysAhead = defaults.object(forKey: "bookingDaysAhead") as? Int ?? 14
        if let data = defaults.data(forKey: "bookingDays"),
           let days = try? JSONDecoder().decode(Set<Int>.self, from: data) {
            self._bookingDays = days
        }
        if let data = defaults.data(forKey: "worldClockIds"),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            self.worldClockIds = ids
        } else {
            self.worldClockIds = ["America/New_York"]
        }
        if let data = defaults.data(forKey: "disabledCalendarIds") {
            self._disabledCalendarIds = (try? JSONDecoder().decode(Set<String>.self, from: data)) ?? []
        }
    }

    @Published var leadTimeSeconds: Int = 45 {
        didSet { defaults.set(leadTimeSeconds, forKey: "leadTimeSeconds") }
    }

    @Published var volume: Double = 0.75 {
        didSet { defaults.set(volume, forKey: "volume") }
    }

    @Published var countdownSoundEnabled: Bool = false {
        didSet { defaults.set(countdownSoundEnabled, forKey: "countdownSoundEnabled") }
    }

    @Published var showPastMeetings: Bool = false {
        didSet { defaults.set(showPastMeetings, forKey: "showPastMeetings") }
    }

    @Published var hideEmptyDays: Bool = false {
        didSet { defaults.set(hideEmptyDays, forKey: "hideEmptyDays") }
    }

    @Published var launchAtLogin: Bool = false {
        didSet { defaults.set(launchAtLogin, forKey: "launchAtLogin") }
    }

    @Published var trackStats: Bool = true {
        didSet { defaults.set(trackStats, forKey: "trackStats") }
    }

    @Published var customSoundPath: String? {
        didSet { defaults.set(customSoundPath, forKey: "customSoundPath") }
    }

    @Published var accentColorHex: String = "#E6402E" {
        didSet { defaults.set(accentColorHex, forKey: "accentColorHex") }
    }

    @Published var use24HourTime: Bool = false {
        didSet { defaults.set(use24HourTime, forKey: "use24HourTime") }
    }

    @Published var showYearProgress: Bool = true {
        didSet { defaults.set(showYearProgress, forKey: "showYearProgress") }
    }

    @Published var showCalendarHeatmap: Bool = true {
        didSet { defaults.set(showCalendarHeatmap, forKey: "showCalendarHeatmap") }
    }

    /// Minutes before meeting end to show wrap-up alert. 0 = disabled.
    @Published var wrapUpMinutes: Int = 2 {
        didSet { defaults.set(wrapUpMinutes, forKey: "wrapUpMinutes") }
    }

    // MARK: - Focus Blocks

    @Published var focusCalendarId: String? = nil {
        didSet { defaults.set(focusCalendarId, forKey: "focusCalendarId") }
    }

    // MARK: - Commute

    @Published var showCommute: Bool = false {
        didSet { defaults.set(showCommute, forKey: "showCommute") }
    }

    @Published var morningCommuteHour: Int = 8 {
        didSet { defaults.set(morningCommuteHour, forKey: "morningCommuteHour") }
    }

    @Published var morningCommuteMinute: Int = 30 {
        didSet { defaults.set(morningCommuteMinute, forKey: "morningCommuteMinute") }
    }

    @Published var eveningCommuteHour: Int = 18 {
        didSet { defaults.set(eveningCommuteHour, forKey: "eveningCommuteHour") }
    }

    @Published var eveningCommuteMinute: Int = 0 {
        didSet { defaults.set(eveningCommuteMinute, forKey: "eveningCommuteMinute") }
    }

    @Published var commuteDurationMinutes: Int = 30 {
        didSet { defaults.set(commuteDurationMinutes, forKey: "commuteDurationMinutes") }
    }

    /// Days of week for commute. 1=Sun, 2=Mon, ..., 7=Sat
    @Published private var _commuteDays: Set<Int> = [2, 3, 4, 5, 6] {
        didSet {
            let data = try? JSONEncoder().encode(_commuteDays)
            defaults.set(data, forKey: "commuteDays")
        }
    }

    var commuteDays: Set<Int> {
        get { _commuteDays }
        set { _commuteDays = newValue }
    }

    func isCommuteDay(_ weekday: Int) -> Bool {
        _commuteDays.contains(weekday)
    }

    func toggleCommuteDay(_ weekday: Int) {
        if _commuteDays.contains(weekday) {
            _commuteDays.remove(weekday)
        } else {
            _commuteDays.insert(weekday)
        }
    }

    /// Returns morning commute start/end for today, or nil if not a commute day
    func morningCommuteToday() -> (start: Date, end: Date)? {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date())
        guard showCommute, isCommuteDay(weekday) else { return nil }
        guard let start = cal.date(bySettingHour: morningCommuteHour, minute: morningCommuteMinute, second: 0, of: Date()),
              let end = cal.date(byAdding: .minute, value: commuteDurationMinutes, to: start) else { return nil }
        return (start, end)
    }

    /// Returns evening commute start/end for today, or nil if not a commute day
    func eveningCommuteToday() -> (start: Date, end: Date)? {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date())
        guard showCommute, isCommuteDay(weekday) else { return nil }
        guard let start = cal.date(bySettingHour: eveningCommuteHour, minute: eveningCommuteMinute, second: 0, of: Date()),
              let end = cal.date(byAdding: .minute, value: commuteDurationMinutes, to: start) else { return nil }
        return (start, end)
    }

    // MARK: - Booking (Calendly)

    @Published var bookingEnabled: Bool = false {
        didSet { defaults.set(bookingEnabled, forKey: "bookingEnabled") }
    }

    @Published var bookingName: String = "" {
        didSet { defaults.set(bookingName, forKey: "bookingName") }
    }

    @Published var bookingStartHour: Int = 9 {
        didSet { defaults.set(bookingStartHour, forKey: "bookingStartHour") }
    }

    @Published var bookingEndHour: Int = 17 {
        didSet { defaults.set(bookingEndHour, forKey: "bookingEndHour") }
    }

    @Published var bookingSlotMinutes: Int = 30 {
        didSet { defaults.set(bookingSlotMinutes, forKey: "bookingSlotMinutes") }
    }

    @Published var bookingBufferMinutes: Int = 10 {
        didSet { defaults.set(bookingBufferMinutes, forKey: "bookingBufferMinutes") }
    }

    @Published var bookingDaysAhead: Int = 14 {
        didSet { defaults.set(bookingDaysAhead, forKey: "bookingDaysAhead") }
    }

    @Published private var _bookingDays: Set<Int> = [2, 3, 4, 5, 6] {
        didSet {
            let data = try? JSONEncoder().encode(_bookingDays)
            defaults.set(data, forKey: "bookingDays")
        }
    }

    var bookingDays: Set<Int> {
        get { _bookingDays }
        set { _bookingDays = newValue }
    }

    func isBookingDay(_ weekday: Int) -> Bool {
        _bookingDays.contains(weekday)
    }

    func toggleBookingDay(_ weekday: Int) {
        if _bookingDays.contains(weekday) {
            _bookingDays.remove(weekday)
        } else {
            _bookingDays.insert(weekday)
        }
    }

    @Published var worldClockIds: [String] = [] {
        didSet {
            let data = try? JSONEncoder().encode(worldClockIds)
            defaults.set(data, forKey: "worldClockIds")
        }
    }

    @Published private var _disabledCalendarIds: Set<String> = [] {
        didSet {
            let data = try? JSONEncoder().encode(_disabledCalendarIds)
            defaults.set(data, forKey: "disabledCalendarIds")
        }
    }

    var disabledCalendarIds: Set<String> {
        get { _disabledCalendarIds }
        set { _disabledCalendarIds = newValue }
    }

    func isCalendarEnabled(_ calendarId: String) -> Bool {
        !_disabledCalendarIds.contains(calendarId)
    }

    func toggleCalendar(_ calendarId: String) {
        if _disabledCalendarIds.contains(calendarId) {
            _disabledCalendarIds.remove(calendarId)
        } else {
            _disabledCalendarIds.insert(calendarId)
        }
    }

}
