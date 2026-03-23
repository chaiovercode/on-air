import Foundation

struct MeetingRecord: Codable, Identifiable {
    let id: UUID
    let title: String
    let date: Date
    let startTime: Date
    let endTime: Date
    let durationMinutes: Int
    let platform: String?
    let calendarName: String

    init(from event: CalendarEvent) {
        self.id = UUID()
        self.title = event.title
        self.date = event.startDate
        self.startTime = event.startDate
        self.endTime = event.endDate
        self.durationMinutes = event.durationMinutes
        self.platform = event.meetingLink?.platform.displayName
        self.calendarName = event.calendarTitle
    }
}
