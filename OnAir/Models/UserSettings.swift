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
        self.showPastMeetings = defaults.bool(forKey: "showPastMeetings")
        self.hideEmptyDays = defaults.bool(forKey: "hideEmptyDays")
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        self.trackStats = defaults.object(forKey: "trackStats") as? Bool ?? true
        self.customSoundPath = defaults.string(forKey: "customSoundPath")
        self.accentColorHex = defaults.string(forKey: "accentColorHex") ?? "#E6402E"
        self.use24HourTime = defaults.bool(forKey: "use24HourTime")
        self.showYearProgress = defaults.object(forKey: "showYearProgress") as? Bool ?? true
        self.showSunArc = defaults.object(forKey: "showSunArc") as? Bool ?? true
        self.showCalendarHeatmap = defaults.object(forKey: "showCalendarHeatmap") as? Bool ?? true
        self.wrapUpMinutes = defaults.object(forKey: "wrapUpMinutes") as? Int ?? 2
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

    @Published var showSunArc: Bool = true {
        didSet { defaults.set(showSunArc, forKey: "showSunArc") }
    }

    @Published var showCalendarHeatmap: Bool = true {
        didSet { defaults.set(showCalendarHeatmap, forKey: "showCalendarHeatmap") }
    }

    /// Minutes before meeting end to show wrap-up alert. 0 = disabled.
    @Published var wrapUpMinutes: Int = 2 {
        didSet { defaults.set(wrapUpMinutes, forKey: "wrapUpMinutes") }
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
