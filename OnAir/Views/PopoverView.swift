import Collaboration
import SwiftUI

struct PopoverView: View {

    @ObservedObject var appState: AppState
    @State private var displayedMonth = Date()
    @State private var selectedDate: Date? = nil
    @State private var calendarCollapsed = false
    @State private var showSearch = false
    @State private var showNewEvent = false

    private let accentRed = Color(red: 0.9, green: 0.25, blue: 0.2)

    private var themeBorder: Color {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 18 || hour < 6 {
            return Color(red: 0.30, green: 0.32, blue: 0.45).opacity(0.35)
        }
        return Color(red: 0.45, green: 0.32, blue: 0.20).opacity(0.35)
    }

    private var themeFill: Color {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 18 || hour < 6 {
            return .white.opacity(0.05)
        }
        return .white.opacity(0.03)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Arrow notch pointing up
            Triangle()
                .fill(Color(red: 0.12, green: 0.11, blue: 0.10))
                .frame(width: 16, height: 8)
                .padding(.top, 2)

            // Top card: header + greeting
            VStack(spacing: 0) {
                headerToolbar
                    .padding(.bottom, 8)
                greetingCard
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(themeFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(themeBorder, lineWidth: 0.5)
            )
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if appState.calendarAccessDenied {
                calendarAccessView
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
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
                        AgendaView(appState: appState, selectedDate: selectedDate) {
                            showSearch = false
                            showNewEvent.toggle()
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                    }
                }

                // Footer
                footer
            }
        }
        .frame(width: 300, height: 700)
        .background(
            ZStack {
                Color(red: 0.12, green: 0.11, blue: 0.10)
                VStack {
                    LinearGradient(
                        stops: topGradientStops,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 160)
                    Spacer()
                }
            }
        )
        .overlay {
            if showSearch || showNewEvent {
                Color.black.opacity(0.4)
                    .onTapGesture { showSearch = false; showNewEvent = false }
            }
        }
        .overlay(alignment: .top) {
            if showSearch {
                SearchView(appState: appState, isPresented: $showSearch)
                    .padding(.horizontal, 2)
                    .frame(maxHeight: 480)
                    .background(Color(red: 0.10, green: 0.10, blue: 0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.6), radius: 24, y: 8)
                    .padding(.top, 100)
            }
        }
        .overlay(alignment: .top) {
            if showNewEvent {
                NewEventView(appState: appState, isPresented: $showNewEvent)
                    .padding(.horizontal, 2)
                    .background(Color(red: 0.10, green: 0.10, blue: 0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.6), radius: 24, y: 8)
                    .padding(.top, 160)
            }
        }
    }

    // MARK: - Header Toolbar (Dot-style)

    private var headerToolbar: some View {
        HStack(spacing: 0) {
            // Date + icon
            HStack(spacing: 6) {
                Text(timeOfDayEmoji)
                    .font(.system(size: 12))
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
                    showSearch = false
                    showNewEvent.toggle()
                }
                headerButton(icon: "magnifyingglass", help: "Search ⌘F") {
                    showNewEvent = false
                    showSearch.toggle()
                }
                headerButton(icon: calendarCollapsed ? "chevron.down" : "chevron.up", help: "Toggle Calendar") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        calendarCollapsed.toggle()
                    }
                }
                headerButton(icon: "gearshape", help: "Settings ⌘,") {
                    showSearch = false
                    showNewEvent = false
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
            HStack(spacing: 0) {
                Text("\(greeting), ")
                    .font(.system(size: 13, weight: .semibold))
                if let nsImage = userProfileImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                        .padding(.trailing, 4)
                }
                Text("\(firstName).")
                    .font(.system(size: 13, weight: .semibold))
            }

            if hasUpcomingEvents {
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
            } else {
                Text(allClearMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(themeFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(themeBorder, lineWidth: 0.5)
        )
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var hasUpcomingEvents: Bool {
        appState.todayEvents.contains { $0.endDate > Date() }
    }

    private var topGradientStops: [Gradient.Stop] {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 18 || hour < 6 {
            // Night — cool blue/indigo tint
            return [
                .init(color: Color(red: 0.14, green: 0.14, blue: 0.24).opacity(0.7), location: 0),
                .init(color: Color(red: 0.12, green: 0.12, blue: 0.18).opacity(0.3), location: 0.4),
                .init(color: .clear, location: 1.0)
            ]
        } else if hour >= 6 && hour < 12 {
            // Morning — warm golden
            return [
                .init(color: Color(red: 0.30, green: 0.22, blue: 0.10).opacity(0.6), location: 0),
                .init(color: Color(red: 0.22, green: 0.16, blue: 0.08).opacity(0.3), location: 0.4),
                .init(color: .clear, location: 1.0)
            ]
        } else {
            // Afternoon — warm amber
            return [
                .init(color: Color(red: 0.28, green: 0.18, blue: 0.10).opacity(0.6), location: 0),
                .init(color: Color(red: 0.20, green: 0.14, blue: 0.08).opacity(0.3), location: 0.4),
                .init(color: .clear, location: 1.0)
            ]
        }
    }

    private var allClearMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 18 { return "All clear for the night." }
        if hour >= 12 { return "All clear for the evening." }
        return "All clear for today."
    }

    private var firstName: String {
        NSFullUserName().components(separatedBy: " ").first ?? "there"
    }

    private var userProfileImage: NSImage? {
        CBIdentity(name: NSUserName(), authority: .local())?.image
    }

    private var timeOfDayEmoji: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 6 && hour < 18 { return "✱" }
        return "☾"
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
        Text(worldClockLine)
            .font(.system(size: 12))
            .foregroundStyle(Color.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
    }

    private var worldClockLine: String {
        appState.settings.worldClockIds.prefix(3).compactMap { tzId -> String? in
            guard let tz = TimeZone(identifier: tzId) else { return nil }
            let h = Calendar.current.dateComponents(in: tz, from: Date()).hour ?? 0
            let icon = (h >= 6 && h < 18) ? "✱" : "☾"
            let city = String((tz.identifier.components(separatedBy: "/").last ?? "")
                .replacingOccurrences(of: "_", with: " ").uppercased().prefix(3))
            let fmt = DateFormatter(); fmt.dateFormat = "h:mma"; fmt.timeZone = tz
            let t = String(fmt.string(from: Date()).lowercased().dropLast(1))
            return "\(icon) \(city)  \(t)"
        }.joined(separator: "  ·  ")
    }

    // MARK: - Actions

    private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
}

// MARK: - Arrow Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
