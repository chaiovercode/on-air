# OnAir: Stats + Liquid Glass — Design Spec

**Date:** 2026-03-24
**Status:** Approved
**Parent spec:** `docs/superpowers/specs/2026-03-23-onair-design.md`

## Summary

Add meeting attendance stats tracking and apply Apple's liquid glass design language across the entire OnAir popover UI. Bumps minimum deployment target to macOS 26.

## Feature 1: Meeting Stats

### Data Model — MeetingRecord

When a meeting transitions to "in progress" (startDate passes while it's the next event), persist a record:

```swift
struct MeetingRecord: Codable, Identifiable {
    let id: UUID
    let title: String
    let date: Date
    let startTime: Date
    let endTime: Date
    let durationMinutes: Int
    let platform: String?    // "Google Meet", "Zoom", "Teams", "Webex", nil
    let calendarName: String
}
```

**Storage:** JSON array at `~/Library/Application Support/OnAir/stats.json`. Append-only during normal operation. Full overwrite on "Clear Stats".

### StatsService

- `recordAttendance(_ event: CalendarEvent)` — creates a MeetingRecord and appends to JSON
- `loadRecords() -> [MeetingRecord]` — reads all records from disk
- `clearAll()` — deletes the stats file
- Computed stats (all derived from the records array):
  - `meetingsThisWeek: Int`
  - `meetingsThisMonth: Int`
  - `totalMeetings: Int`
  - `totalHours: Double`
  - `busiestDays: [(dayOfWeek: String, count: Int, percentage: Double)]` — sorted desc
  - `platformBreakdown: [(platform: String, count: Int, percentage: Double)]` — sorted desc
  - `peakHours: [(hour: String, count: Int, percentage: Double)]` — sorted desc
  - `topMeetings: [(title: String, count: Int)]` — grouped by exact title match, sorted desc, top 5

### AppState Integration

- When `nextEvent` transitions from "upcoming" to "in progress" (remaining goes from >0 to <=0), call `statsService.recordAttendance(event)`
- Only record if `settings.trackStats` is true
- Guard against double-recording the same event (track last recorded event ID)

### StatsView

Three-tab navigation at the top of the popover: **Meetings | Stats | Settings**

Stats tab shows scrollable cards:
1. **Summary card:** This week count, this month count, total hours
2. **Busiest Day card:** horizontal bar chart (day name + bar + percentage)
3. **Platforms card:** horizontal bar chart (platform name + bar + percentage)
4. **Peak Hours card:** horizontal bar chart (hour range + bar + label)
5. **Top Meetings card:** list of meeting titles with occurrence count

All bars are simple `Rectangle` fills with proportional widths — no charting library needed.

### Settings Additions

- `trackStats: Bool` (default: true) — toggle in settings
- "Clear Stats" button — shows confirmation alert, then calls `statsService.clearAll()`

## Feature 2: Liquid Glass UI

### Deployment Target

Bump from macOS 13 to macOS 26 in `project.yml`.

### Where to Apply

| Component | Glass Treatment |
|-----------|----------------|
| Popover container | `.glassEffect()` on root VStack |
| Tab bar (segmented control) | Glass-styled `Picker` |
| Meeting rows | `.glassEffect()` on each row container |
| Join buttons | Glass button style |
| Stats cards | `.glassEffect()` on each card |
| Settings sections | `.glassEffect()` on section containers |
| Footer | Glass background |

### Navigation Change

Replace the current binary `showSettings` toggle with a three-tab enum:

```swift
enum PopoverTab: String, CaseIterable {
    case meetings, stats, settings
}
```

Rendered as a segmented `Picker` in the popover header.

## Files

### New Files
- `OnAir/Models/MeetingRecord.swift` — record struct
- `OnAir/Services/StatsService.swift` — persistence + computation
- `OnAir/Views/StatsView.swift` — stats display

### Modified Files
- `OnAir/State/AppState.swift` — track attendance on meeting start
- `OnAir/Models/UserSettings.swift` — add `trackStats` setting
- `OnAir/Views/PopoverView.swift` — three-tab navigation + glass effects
- `OnAir/Views/MeetingRowView.swift` — glass card styling
- `OnAir/Views/SettingsView.swift` — stats toggle, clear button, glass sections
- `OnAir/Views/StatusBarManager.swift` — update popover content size
- `project.yml` — bump deployment target to macOS 26

## Non-Goals

- Historical data import (only tracks from first launch onward)
- Per-attendee tracking (no access to attendee names via EventKit without additional permissions)
- Data export
- Charts library (simple SwiftUI rectangles for bars)
