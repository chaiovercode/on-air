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
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Content
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
            .frame(maxHeight: .infinity)

            // Footer
            footer
                .padding(.top, 4)
        }
        .frame(width: 360, height: 500)
    }

    // MARK: - Meetings Tab

    private var meetingListView: some View {
        VStack(spacing: 0) {
            if appState.calendarAccessDenied {
                calendarAccessView
            } else if visibleEvents.isEmpty {
                noMeetingsView
            } else {
                header
                meetingsList
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(.system(size: 16, weight: .bold))

                Text(Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(visibleEvents.count)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.red)
            + Text(" meeting\(visibleEvents.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var meetingsList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(visibleEvents) { event in
                    MeetingRowView(
                        event: event,
                        isNext: event.id == appState.nextEvent?.id && !isEventInProgress(event),
                        isInProgress: isEventInProgress(event),
                        isPast: event.endDate <= Date()
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private var calendarAccessView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.orange)

            Text("Calendar Access")
                .font(.system(size: 15, weight: .semibold))

            Text("OnAir needs access to show\nyour meetings.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var noMeetingsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.green.opacity(0.8))

            Text("All clear")
                .font(.system(size: 15, weight: .semibold))

            Text("No meetings today")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Text("Quit")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Helpers

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
