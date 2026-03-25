import Foundation

final class StatsService: ObservableObject {

    @Published private(set) var records: [MeetingRecord] = []

    private let fileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("OnAir")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("stats.json")
    }()

    init() {
        loadRecords()
    }

    func recordAttendance(_ event: CalendarEvent, attendees: [String] = []) {
        // Prevent duplicate recordings
        guard !records.contains(where: { $0.eventId == event.id }) else { return }
        // Only record past meetings
        guard event.endDate <= Date() else { return }
        let record = MeetingRecord(from: event, attendees: attendees)
        records.append(record)
        saveRecords()
    }

    func backfillAttendees(eventId: String, names: [String]) {
        guard !names.isEmpty else { return }
        guard let index = records.firstIndex(where: { $0.eventId == eventId && $0.attendees.isEmpty }) else { return }
        records[index].attendees = names
        saveRecords()
    }

    func clearAll() {
        records = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Computed Stats

    var meetingsThisWeek: Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return records.filter { $0.date >= startOfWeek }.count
    }

    var meetingsThisMonth: Int {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        return records.filter { $0.date >= startOfMonth }.count
    }

    var totalMeetings: Int { records.count }

    var totalHours: Double {
        Double(records.reduce(0) { $0 + $1.durationMinutes }) / 60.0
    }

    var totalHoursDisplay: String {
        let hours = Int(totalHours)
        let mins = Int((totalHours - Double(hours)) * 60)
        if hours == 0 { return "\(mins)m" }
        return "\(hours)h \(mins)m"
    }

    var hoursThisWeek: Double {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekRecords = records.filter { $0.date >= startOfWeek }
        return Double(weekRecords.reduce(0) { $0 + $1.durationMinutes }) / 60.0
    }

    var hoursThisWeekDisplay: String {
        let hours = Int(hoursThisWeek)
        let mins = Int((hoursThisWeek - Double(hours)) * 60)
        if hours == 0 { return "\(mins)m" }
        return "\(hours)h \(mins)m"
    }

    var avgDurationMinutes: Int {
        guard !records.isEmpty else { return 0 }
        return records.reduce(0) { $0 + $1.durationMinutes } / records.count
    }

    var avgDurationDisplay: String {
        let hours = avgDurationMinutes / 60
        let mins = avgDurationMinutes % 60
        if hours == 0 { return "\(mins)m" }
        return "\(hours)h \(mins)m"
    }

    var busiestDays: [(dayOfWeek: String, count: Int, percentage: Double)] {
        let calendar = Calendar.current
        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        var counts = [Int: Int]()
        for record in records {
            let weekday = calendar.component(.weekday, from: record.date)
            counts[weekday, default: 0] += 1
        }
        let total = max(records.count, 1)
        return counts
            .map { (dayOfWeek: dayNames[$0.key - 1], count: $0.value, percentage: Double($0.value) / Double(total) * 100) }
            .sorted { $0.count > $1.count }
    }

    var platformBreakdown: [(platform: String, count: Int, percentage: Double)] {
        var counts = [String: Int]()
        for record in records {
            let platform = record.platform ?? "No link"
            counts[platform, default: 0] += 1
        }
        let total = max(records.count, 1)
        return counts
            .map { (platform: $0.key, count: $0.value, percentage: Double($0.value) / Double(total) * 100) }
            .sorted { $0.count > $1.count }
    }

    var peakHours: [(hour: String, count: Int, percentage: Double)] {
        let calendar = Calendar.current
        var counts = [Int: Int]()
        for record in records {
            let hour = calendar.component(.hour, from: record.startTime)
            counts[hour, default: 0] += 1
        }
        let total = max(records.count, 1)
        return counts
            .map { hour, count in
                let startHour = hour % 12 == 0 ? 12 : hour % 12
                let endHour = (hour + 1) % 12 == 0 ? 12 : (hour + 1) % 12
                let period = hour < 12 ? "AM" : "PM"
                let endPeriod = (hour + 1) < 12 || (hour + 1) == 24 ? "AM" : "PM"
                let label = "\(startHour) \(period)–\(endHour) \(endPeriod)"
                return (hour: label, count: count, percentage: Double(count) / Double(total) * 100)
            }
            .sorted { $0.count > $1.count }
    }

    var topMeetings: [(title: String, count: Int)] {
        var counts = [String: Int]()
        for record in records {
            counts[record.title, default: 0] += 1
        }
        return counts
            .map { (title: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }

    var topAttendees: [(name: String, count: Int)] {
        var counts = [String: Int]()
        for record in records {
            for name in record.attendees {
                counts[name, default: 0] += 1
            }
        }
        return counts
            .map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Persistence

    private func loadRecords() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            records = try JSONDecoder().decode([MeetingRecord].self, from: data)
        } catch {
            records = []
        }
    }

    private func saveRecords() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Silent fail — stats are non-critical
        }
    }
}
