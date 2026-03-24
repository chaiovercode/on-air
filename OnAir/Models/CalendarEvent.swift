import Foundation

struct CalendarEvent: Identifiable, Equatable, Comparable {

    enum Status: String {
        case confirmed, tentative, cancelled
    }

    enum ParticipationStatus: String {
        case accepted, declined, tentative, pending
    }

    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let status: Status
    let participationStatus: ParticipationStatus
    let calendarTitle: String
    let calendarId: String
    let calendarColorHex: String

    var meetingLink: MeetingPlatform? {
        if let link = MeetingPlatform.detect(from: location) {
            return link
        }
        return MeetingPlatform.detect(from: notes)
    }

    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }

    var durationDisplay: String {
        let mins = durationMinutes
        if mins >= 60 && mins % 60 == 0 {
            return "\(mins / 60) hr"
        } else if mins >= 60 {
            return "\(mins / 60) hr \(mins % 60) min"
        } else {
            return "\(mins) min"
        }
    }

    var shouldShow: Bool {
        guard !isAllDay else { return false }
        guard status != .cancelled else { return false }
        guard participationStatus != .declined else { return false }
        return true
    }

    var hasLink: Bool {
        meetingLink != nil
    }

    func overlaps(with other: CalendarEvent) -> Bool {
        guard id != other.id else { return false }
        return startDate < other.endDate && endDate > other.startDate
    }

    static func < (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        if lhs.startDate != rhs.startDate {
            return lhs.startDate < rhs.startDate
        }
        if lhs.hasLink != rhs.hasLink {
            return lhs.hasLink
        }
        if lhs.durationMinutes != rhs.durationMinutes {
            return lhs.durationMinutes < rhs.durationMinutes
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}
