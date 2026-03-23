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
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Tab content
            Group {
                switch selectedTab {
                case .meetings:
                    meetingListView
                case .stats:
                    StatsView(statsService: appState.statsService)
                case .settings:
                    SettingsView(appState: appState, settings: appState.settings)
                }
            }

            Spacer(minLength: 0)

            // Footer
            footer
        }
        .frame(width: 340, height: 480)
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
        VStack(alignment: .leading, spacing: 3) {
            Text("Today")
                .font(.system(size: 15, weight: .semibold))

            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            + Text(" · \(visibleEvents.count) meeting\(visibleEvents.count == 1 ? "" : "s")")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var meetingsList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(visibleEvents) { event in
                    MeetingRowView(
                        event: event,
                        isNext: event.id == appState.nextEvent?.id && !isEventInProgress(event),
                        isInProgress: isEventInProgress(event),
                        isPast: event.endDate <= Date()
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 340)
    }

    private var calendarAccessView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(.orange)

            Text("Calendar Access Needed")
                .font(.system(size: 13, weight: .medium))

            Text("Grant access in System Settings → Privacy & Security → Calendars")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(30)
    }

    private var noMeetingsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 24))
                .foregroundStyle(.green)
            Text("No meetings today")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }

    private var footer: some View {
        HStack {
            if appState.soundWarning {
                Label("Sound issue", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit OnAir", systemImage: "power")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
