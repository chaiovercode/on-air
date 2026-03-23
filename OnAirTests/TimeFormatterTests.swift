import XCTest
@testable import OnAir

final class TimeFormatterTests: XCTestCase {

    func testFormats2Hours15Minutes() {
        XCTAssertEqual(TimeFormatter.format(seconds: 8100), "2h 15m")
    }

    func testFormatsExactly1Hour() {
        XCTAssertEqual(TimeFormatter.format(seconds: 3600), "1h 0m")
    }

    func testFormats1Hour30Minutes() {
        XCTAssertEqual(TimeFormatter.format(seconds: 5400), "1h 30m")
    }

    func testFormats37Minutes() {
        XCTAssertEqual(TimeFormatter.format(seconds: 2220), "37m")
    }

    func testFormats5MinutesExactly() {
        XCTAssertEqual(TimeFormatter.format(seconds: 300), "5m")
    }

    func testFormats12Minutes() {
        XCTAssertEqual(TimeFormatter.format(seconds: 720), "12m")
    }

    func testFormats4Minutes30Seconds() {
        XCTAssertEqual(TimeFormatter.format(seconds: 270), "4m 30s")
    }

    func testFormats1MinuteExactly() {
        XCTAssertEqual(TimeFormatter.format(seconds: 60), "1m 0s")
    }

    func testFormats2Minutes45Seconds() {
        XCTAssertEqual(TimeFormatter.format(seconds: 165), "2m 45s")
    }

    func testFormats45Seconds() {
        XCTAssertEqual(TimeFormatter.format(seconds: 45), "45s")
    }

    func testFormats1Second() {
        XCTAssertEqual(TimeFormatter.format(seconds: 1), "1s")
    }

    func testFormats0Seconds() {
        XCTAssertEqual(TimeFormatter.format(seconds: 0), "now")
    }

    func testFormatsNegativeAsNow() {
        XCTAssertEqual(TimeFormatter.format(seconds: -10), "now")
    }

    func testFormats299Seconds() {
        XCTAssertEqual(TimeFormatter.format(seconds: 299), "4m 59s")
    }

    func testFormats59Seconds() {
        XCTAssertEqual(TimeFormatter.format(seconds: 59), "59s")
    }
}
