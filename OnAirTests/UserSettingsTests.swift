import XCTest
@testable import OnAir

final class UserSettingsTests: XCTestCase {

    override func setUp() {
        let defaults = UserDefaults.standard
        UserSettings.allKeys.forEach { defaults.removeObject(forKey: $0) }
    }

    func testDefaultLeadTimeIs45Seconds() {
        let settings = UserSettings()
        XCTAssertEqual(settings.leadTimeSeconds, 45)
    }

    func testDefaultVolumeIs75Percent() {
        let settings = UserSettings()
        XCTAssertEqual(settings.volume, 0.75, accuracy: 0.01)
    }

    func testDefaultShowPastMeetingsIsFalse() {
        let settings = UserSettings()
        XCTAssertFalse(settings.showPastMeetings)
    }

    func testDefaultLaunchAtLoginIsFalse() {
        let settings = UserSettings()
        XCTAssertFalse(settings.launchAtLogin)
    }

    func testLeadTimePresets() {
        let presets = UserSettings.LeadTimePreset.allCases
        XCTAssertEqual(presets.map(\.seconds), [30, 45, 60, 120, 300])
        XCTAssertEqual(presets.map(\.displayName), ["30 seconds", "45 seconds", "1 minute", "2 minutes", "5 minutes"])
    }

    func testCustomSoundPathDefaultsToNil() {
        let settings = UserSettings()
        XCTAssertNil(settings.customSoundPath)
    }

    func testAllCalendarsEnabledByDefault() {
        let settings = UserSettings()
        XCTAssertTrue(settings.isCalendarEnabled("cal-1"))
        XCTAssertTrue(settings.isCalendarEnabled("cal-2"))
    }

    func testToggleCalendarDisablesIt() {
        let settings = UserSettings()
        settings.toggleCalendar("cal-1")
        XCTAssertFalse(settings.isCalendarEnabled("cal-1"))
        XCTAssertTrue(settings.isCalendarEnabled("cal-2"))
    }

    func testToggleCalendarTwiceReEnablesIt() {
        let settings = UserSettings()
        settings.toggleCalendar("cal-1")
        settings.toggleCalendar("cal-1")
        XCTAssertTrue(settings.isCalendarEnabled("cal-1"))
    }

    func testDisabledCalendarIdsPersisted() {
        let settings = UserSettings()
        settings.toggleCalendar("cal-1")
        XCTAssertTrue(settings.disabledCalendarIds.contains("cal-1"))
    }
}
