import SwiftUI

enum PopoverTab: String, CaseIterable {
    case meetings = "Meetings"
    case stats = "Stats"
    case settings = "Settings"
}

struct PopoverView: View {

    @ObservedObject var appState: AppState
    @State private var selectedTab: PopoverTab = .meetings

    private let accentRed = Color(red: 0.9, green: 0.25, blue: 0.2)

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            toolbar
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

            // Content
            Group {
                switch selectedTab {
                case .meetings:
                    meetingsContent
                case .stats:
                    StatsView(statsService: appState.statsService)
                case .settings:
                    SettingsView(appState: appState, settings: appState.settings)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 360, height: 520)
    }

    // MARK: - Toolbar (Dot-style)

    private var toolbar: some View {
        HStack(spacing: 0) {
            // Date display
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(accentRed)
                Text(Date().formatted(.dateTime.weekday(.abbreviated).day(.defaultDigits).month(.abbreviated)))
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(0.06))
            )

            Spacer()

            // Tab buttons
            HStack(spacing: 2) {
                toolbarButton(icon: "calendar", tab: .meetings)
                toolbarButton(icon: "chart.bar", tab: .stats)
                toolbarButton(icon: "gearshape", tab: .settings)
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
        }
    }

    private func toolbarButton(icon: String, tab: PopoverTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                .frame(width: 28, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(selectedTab == tab ? .white.opacity(0.1) : .clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Meetings Content

    private var meetingsContent: some View {
        VStack(spacing: 0) {
            if appState.calendarAccessDenied {
                calendarAccessView
            } else {
                // Summary card (Dot-style greeting)
                summaryCard
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)

                // Events list
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if !todayEvents.isEmpty {
                            sectionHeader("TODAY")
                            ForEach(todayEvents) { event in
                                MeetingRowView(
                                    event: event,
                                    isNext: event.id == appState.nextEvent?.id && !isInProgress(event),
                                    isInProgress: isInProgress(event),
                                    isPast: event.endDate <= Date(),
                                    accentRed: accentRed
                                )
                            }
                        } else {
                            noMeetingsView
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }

                // Footer
                footer
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Text(greeting)
                    .font(.system(size: 13, weight: .medium))
                Text(" You have ")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("\(todayEvents.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accentRed)
                Text(" event\(todayEvents.count == 1 ? "" : "s") today.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning." }
        if hour < 17 { return "Good afternoon." }
        return "Good evening."
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accentRed)
                .tracking(1.5)

            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    // MARK: - States

    private var calendarAccessView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.orange)

            Text("Calendar Access Needed")
                .font(.system(size: 14, weight: .semibold))

            Text("Grant access in System Settings\n→ Privacy & Security → Calendars")
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
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 22))
                .foregroundStyle(.green.opacity(0.7))
            Text("All clear — no meetings today")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Footer

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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private var todayEvents: [CalendarEvent] {
        if appState.settings.showPastMeetings {
            return appState.todayEvents
        }
        return appState.todayEvents.filter { $0.endDate > Date() }
    }

    private func isInProgress(_ event: CalendarEvent) -> Bool {
        event.startDate <= Date() && event.endDate > Date()
    }
}
