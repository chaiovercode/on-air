import XCTest
@testable import OnAir

final class CalendarEventTests: XCTestCase {

    private func makeEvent(
        title: String = "Test",
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(1800),
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        status: CalendarEvent.Status = .confirmed,
        participationStatus: CalendarEvent.ParticipationStatus = .accepted
    ) -> CalendarEvent {
        CalendarEvent(
            id: UUID().uuidString,
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location,
            notes: notes,
            status: status,
            participationStatus: participationStatus,
            calendarTitle: "Work",
            calendarId: "cal-1",
            calendarColorHex: "#4285F4"
        )
    }

    func testDetectsMeetingLinkFromLocation() {
        let event = makeEvent(location: "https://meet.google.com/abc-defg-hij")
        XCTAssertNotNil(event.meetingLink)
        XCTAssertEqual(event.meetingLink?.platform, .googleMeet)
    }

    func testDetectsMeetingLinkFromNotes() {
        let event = makeEvent(notes: "Join: https://zoom.us/j/123456789")
        XCTAssertNotNil(event.meetingLink)
        XCTAssertEqual(event.meetingLink?.platform, .zoom)
    }

    func testPrefersLocationOverNotes() {
        let event = makeEvent(
            location: "https://meet.google.com/abc",
            notes: "https://zoom.us/j/123"
        )
        XCTAssertEqual(event.meetingLink?.platform, .googleMeet)
    }

    func testNoLinkWhenNonePresent() {
        let event = makeEvent(location: "Conference Room 3B")
        XCTAssertNil(event.meetingLink)
    }

    func testDurationInMinutes() {
        let start = Date()
        let event = makeEvent(startDate: start, endDate: start.addingTimeInterval(1800))
        XCTAssertEqual(event.durationMinutes, 30)
    }

    func testDurationDisplayMinutes() {
        let start = Date()
        let event = makeEvent(startDate: start, endDate: start.addingTimeInterval(2700))
        XCTAssertEqual(event.durationDisplay, "45 min")
    }

    func testDurationDisplayHour() {
        let start = Date()
        let event = makeEvent(startDate: start, endDate: start.addingTimeInterval(3600))
        XCTAssertEqual(event.durationDisplay, "1 hr")
    }

    func testDurationDisplayHours() {
        let start = Date()
        let event = makeEvent(startDate: start, endDate: start.addingTimeInterval(7200))
        XCTAssertEqual(event.durationDisplay, "2 hr")
    }

    func testShouldShowReturnsTrueForAccepted() {
        let event = makeEvent(participationStatus: .accepted)
        XCTAssertTrue(event.shouldShow)
    }

    func testShouldShowReturnsTrueForTentative() {
        let event = makeEvent(participationStatus: .tentative)
        XCTAssertTrue(event.shouldShow)
    }

    func testShouldShowReturnsTrueForPending() {
        let event = makeEvent(participationStatus: .pending)
        XCTAssertTrue(event.shouldShow)
    }

    func testShouldShowReturnsFalseForDeclined() {
        let event = makeEvent(participationStatus: .declined)
        XCTAssertFalse(event.shouldShow)
    }

    func testShouldShowReturnsFalseForCancelled() {
        let event = makeEvent(status: .cancelled)
        XCTAssertFalse(event.shouldShow)
    }

    func testShouldShowReturnsFalseForAllDay() {
        let event = makeEvent(isAllDay: true)
        XCTAssertFalse(event.shouldShow)
    }

    func testSortsByStartDate() {
        let early = makeEvent(title: "Early", startDate: Date())
        let late = makeEvent(title: "Late", startDate: Date().addingTimeInterval(3600))
        let sorted = [late, early].sorted()
        XCTAssertEqual(sorted.map(\.title), ["Early", "Late"])
    }

    func testTiebreaksWithLinkOverNoLink() {
        let now = Date()
        let withLink = makeEvent(title: "A", startDate: now, location: "https://meet.google.com/abc")
        let withoutLink = makeEvent(title: "B", startDate: now)
        let sorted = [withoutLink, withLink].sorted()
        XCTAssertEqual(sorted.first?.title, "A")
    }

    func testTiebreaksWithShorterDuration() {
        let now = Date()
        let short = makeEvent(title: "Short", startDate: now, endDate: now.addingTimeInterval(900))
        let long = makeEvent(title: "Long", startDate: now, endDate: now.addingTimeInterval(3600))
        let sorted = [long, short].sorted()
        XCTAssertEqual(sorted.first?.title, "Short")
    }

    func testTiebreaksAlphabetically() {
        let now = Date()
        let end = now.addingTimeInterval(1800)
        let b = makeEvent(title: "Bravo", startDate: now, endDate: end)
        let a = makeEvent(title: "Alpha", startDate: now, endDate: end)
        let sorted = [b, a].sorted()
        XCTAssertEqual(sorted.first?.title, "Alpha")
    }
}
