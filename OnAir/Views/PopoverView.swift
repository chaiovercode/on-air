import SwiftUI

enum PopoverTab: String, CaseIterable {
    case meetings = "Meetings"
    case stats = "Stats"
    case settings = "Settings"
}

struct PopoverView: View {

    @ObservedObject var appState: AppState
    @State private var selectedTab: PopoverTab = .meetings

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            Picker("", selection: $selectedTab) {
                ForEach(PopoverTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Tab content
            switch selectedTab {
            case .meetings:
                meetingListView
            case .stats:
                StatsView(statsService: appState.statsService)
            case .settings:
                SettingsView(appState: appState, settings: appState.settings)
            }

            Divider()

            // Footer
            footer
        }
        .frame(width: 340)
        .glassEffect(.regular.interactive())
    }

    private var meetingListView: some View {
        VStack(spacing: 0) {
            header

            if appState.calendarAccessDenied {
                calendarAccessView
            } else if appState.todayEvents.isEmpty {
                noMeetingsView
            } else {
                meetingsList
            }
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
            LazyVStack(spacing: 6) {
                ForEach(visibleEvents) { event in
                    MeetingRowView(
                        event: event,
                        isNext: event.id == appState.nextEvent?.id && !isEventInProgress(event),
                        isInProgress: isEventInProgress(event),
                        isPast: event.endDate <= Date()
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
            if appState.soundWarning {
                HStack(spacing: 4) {
                    Circle().fill(.orange).frame(width: 6, height: 6)
                    Text("Sound issue — check Settings")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
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
