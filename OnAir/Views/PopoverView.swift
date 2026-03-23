import SwiftUI

struct PopoverView: View {

    @ObservedObject var appState: AppState
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView(appState: appState, showSettings: $showSettings)
            } else {
                meetingListView
            }
        }
        .frame(width: 320)
    }

    private var meetingListView: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if appState.calendarAccessDenied {
                calendarAccessView
            } else if appState.todayEvents.isEmpty {
                noMeetingsView
            } else {
                meetingsList
            }

            Divider()

            footer
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Today")
                .font(.system(size: 13, weight: .semibold))

            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            + Text(" · \(visibleEvents.count) meeting\(visibleEvents.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var meetingsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(visibleEvents) { event in
                    MeetingRowView(
                        event: event,
                        isNext: event.id == appState.nextEvent?.id && !isEventInProgress(event),
                        isInProgress: isEventInProgress(event),
                        isPast: event.endDate <= Date()
                    )
                }
            }
        }
        .frame(maxHeight: 300)
    }

    private var calendarAccessView: some View {
        VStack(spacing: 12) {
            Text("⚠ Calendar Access Needed")
                .font(.system(size: 13, weight: .medium))

            Text("Grant access in System Settings → Privacy & Security → Calendars")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(24)
    }

    private var noMeetingsView: some View {
        VStack(spacing: 8) {
            Text("No meetings today")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(24)
    }

    private var footer: some View {
        HStack {
            Button {
                showSettings = true
            } label: {
                HStack(spacing: 4) {
                    Text("⚙")
                    Text("Settings")
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .overlay {
                if appState.soundWarning {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                        .offset(x: -8, y: -6)
                }
            }

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Text("⏻")
                    Text("Quit OnAir")
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var visibleEvents: [CalendarEvent] {
        if appState.settings.showPastMeetings {
            return appState.todayEvents
        }
        return appState.todayEvents.filter { $0.endDate > Date() }
    }

    private func isEventInProgress(_ event: CalendarEvent) -> Bool {
        event.startDate <= Date() && event.endDate > Date()
    }
}
