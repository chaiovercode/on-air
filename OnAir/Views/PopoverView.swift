import SwiftUI

struct PopoverView: View {

    @ObservedObject var appState: AppState
    @State private var displayedMonth = Date()
    @State private var selectedDate: Date? = nil
    @State private var calendarCollapsed = false
    @State private var showSearch = false
    @State private var showNewEvent = false
    @State private var showSettings = false

    private let accentRed = Color(red: 0.9, green: 0.25, blue: 0.2)

    var body: some View {
        VStack(spacing: 0) {
            // Header toolbar
            headerToolbar
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 6)

            if appState.calendarAccessDenied {
                calendarAccessView
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        // Greeting card
                        greetingCard
                            .padding(.horizontal, 14)
                            .padding(.bottom, 8)

                        // Year progress bar
                        YearProgressView()
                            .padding(.horizontal, 14)
                            .padding(.bottom, 10)

                        // Calendar grid (collapsible)
                        if !calendarCollapsed {
                            CalendarGridView(
                                appState: appState,
                                displayedMonth: $displayedMonth,
                                selectedDate: $selectedDate
                            )
                            .padding(.horizontal, 14)
                            .padding(.bottom, 8)
                        }

                        // Agenda
                        AgendaView(appState: appState, selectedDate: selectedDate)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 12)
                    }
                }

                // Footer
                footer
            }
        }
        .frame(width: 380, height: 600)
    }

    // MARK: - Header Toolbar (Dot-style)

    private var headerToolbar: some View {
        HStack(spacing: 0) {
            // Date + icon
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(accentRed)
                Text(Date().formatted(.dateTime.weekday(.abbreviated).day(.defaultDigits).month(.abbreviated)))
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(0.06))
            )

            Spacer()

            // Action buttons
            HStack(spacing: 2) {
                headerButton(icon: "plus", help: "New Event ⌘N") {
                    showNewEvent.toggle()
                }
                headerButton(icon: "magnifyingglass", help: "Search ⌘F") {
                    showSearch.toggle()
                }
                headerButton(icon: calendarCollapsed ? "chevron.down" : "chevron.up", help: "Toggle Calendar") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        calendarCollapsed.toggle()
                    }
                }
                headerButton(icon: "gearshape", help: "Settings ⌘,") {
                    openSettings()
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
        }
    }

    private func headerButton(icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Greeting Card (Dot-style)

    private var greetingCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 0) {
                Text("You have ")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundStyle(accentRed)
                Text(" \(appState.todayEvents.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accentRed)
                Text(" event\(appState.todayEvents.count == 1 ? "" : "s") today.")
                    .font(.system(size: 12))
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

    // MARK: - Calendar Access

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
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func openSettings() {
        // Open settings window
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        // Fallback: try standard preferences
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
