import Foundation

struct MeetingRecord: Codable, Identifiable {
    let id: UUID
    let eventId: String
    let title: String
    let date: Date
    let startTime: Date
    let endTime: Date
    let durationMinutes: Int
    let platform: String?
    let calendarName: String

    init(from event: CalendarEvent) {
        self.id = UUID()
        self.eventId = event.id
        self.title = event.title
        self.date = event.startDate
        self.startTime = event.startDate
        self.endTime = event.endDate
        self.durationMinutes = event.durationMinutes
        self.platform = event.meetingLink?.platform.displayName
        self.calendarName = event.calendarTitle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        eventId = try c.decodeIfPresent(String.self, forKey: .eventId) ?? UUID().uuidString
        title = try c.decode(String.self, forKey: .title)
        date = try c.decode(Date.self, forKey: .date)
        startTime = try c.decode(Date.self, forKey: .startTime)
        endTime = try c.decode(Date.self, forKey: .endTime)
        durationMinutes = try c.decode(Int.self, forKey: .durationMinutes)
        platform = try c.decodeIfPresent(String.self, forKey: .platform)
        calendarName = try c.decode(String.self, forKey: .calendarName)
    }
}
