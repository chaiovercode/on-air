import XCTest
@testable import OnAir

final class MeetingPlatformTests: XCTestCase {

    func testDetectsGoogleMeetFromURL() {
        let result = MeetingPlatform.detect(from: "https://meet.google.com/abc-defg-hij")
        XCTAssertEqual(result?.platform, .googleMeet)
        XCTAssertEqual(result?.url.absoluteString, "https://meet.google.com/abc-defg-hij")
    }

    func testDetectsZoomFromURL() {
        let result = MeetingPlatform.detect(from: "Join at https://zoom.us/j/123456789")
        XCTAssertEqual(result?.platform, .zoom)
    }

    func testDetectsZoomSubdomainFromURL() {
        let result = MeetingPlatform.detect(from: "https://company.zoom.us/j/123456789")
        XCTAssertEqual(result?.platform, .zoom)
    }

    func testDetectsTeamsFromURL() {
        let result = MeetingPlatform.detect(from: "https://teams.microsoft.com/l/meetup-join/abc123")
        XCTAssertEqual(result?.platform, .teams)
    }

    func testDetectsWebexFromURL() {
        let result = MeetingPlatform.detect(from: "https://company.webex.com/meet/abc123")
        XCTAssertEqual(result?.platform, .webex)
    }

    func testFallbackToGenericHTTPS() {
        let result = MeetingPlatform.detect(from: "Join here: https://example.com/meeting/123")
        XCTAssertEqual(result?.platform, .other)
        XCTAssertEqual(result?.url.absoluteString, "https://example.com/meeting/123")
    }

    func testReturnsNilForNoURL() {
        let result = MeetingPlatform.detect(from: "Conference Room 3B")
        XCTAssertNil(result)
    }

    func testReturnsNilForEmptyString() {
        let result = MeetingPlatform.detect(from: "")
        XCTAssertNil(result)
    }

    func testReturnsNilForNil() {
        let result = MeetingPlatform.detect(from: nil)
        XCTAssertNil(result)
    }

    func testPrefersSpecificPlatformOverGenericURL() {
        let text = "https://example.com/info Join: https://meet.google.com/abc-defg-hij"
        let result = MeetingPlatform.detect(from: text)
        XCTAssertEqual(result?.platform, .googleMeet)
    }

    func testDisplayNames() {
        XCTAssertEqual(MeetingPlatform.Platform.googleMeet.displayName, "Google Meet")
        XCTAssertEqual(MeetingPlatform.Platform.zoom.displayName, "Zoom")
        XCTAssertEqual(MeetingPlatform.Platform.teams.displayName, "Teams")
        XCTAssertEqual(MeetingPlatform.Platform.webex.displayName, "Webex")
        XCTAssertEqual(MeetingPlatform.Platform.other.displayName, "Link")
    }
}
