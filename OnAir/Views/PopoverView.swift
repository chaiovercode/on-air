import Collaboration
import SwiftUI

struct PopoverView: View {

    @ObservedObject var appState: AppState
    @State private var displayedMonth = Date()
    @State private var selectedDate: Date? = nil
    @State private var calendarCollapsed = false
    @State private var scrollToFocus = false
    @State private var greetingIndex = 0

    private var accentRed: Color { Color(hex: appState.settings.accentColorHex) }

    private var themeBorder: Color {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 18 || hour < 6 {
            return Color(red: 0.25, green: 0.27, blue: 0.42).opacity(0.4)
        }
        return Color(red: 0.40, green: 0.28, blue: 0.16).opacity(0.4)
    }

    private var themeFill: Color {
        .white.opacity(0.04)
    }

    var body: some View {
        VStack(spacing: 0) {
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
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 0) {
                            // Year progress bar
                            if appState.settings.showYearProgress {
                                YearProgressView(accentColor: accentRed)
                                    .padding(.horizontal, 14)
                                    .padding(.bottom, 6)
                            }


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
                                NotificationCenter.default.post(name: .toggleNewEvent, object: nil)
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 8)

                            // Focus Timer
                            FocusTimerView(appState: appState)
                                .id("focusTimer")
                                .padding(.horizontal, 14)
                                .padding(.bottom, 12)
                        }
                    }
                    .onChange(of: scrollToFocus) { val in
                        if val {
                            withAnimation { proxy.scrollTo("focusTimer", anchor: .bottom) }
                            scrollToFocus = false
                        }
                    }
                }

                // Footer
                footer
            }
        }
        .frame(width: 300, height: 700)
        .background(
            ZStack {
                Color(red: 0.071, green: 0.063, blue: 0.043)
                VStack {
                    LinearGradient(stops: topGradientStops, startPoint: .top, endPoint: .bottom)
                        .frame(height: 220)
                    Spacer()
                }
            }
        )
    }

    // MARK: - Header Toolbar (Dot-style)

    private var headerToolbar: some View {
        HStack(spacing: 0) {
            // Date + icon
            HStack(spacing: 6) {
                Text(timeOfDayEmoji)
                    .font(.system(size: 12))
                Text(Date(), format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
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
                    NotificationCenter.default.post(name: .toggleNewEvent, object: nil)
                }
                headerButton(icon: "magnifyingglass", help: "Search ⌘F") {
                    NotificationCenter.default.post(name: .toggleSearch, object: nil)
                }
                // Focus button — scrolls to focus timer
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollToFocus = true
                    }
                } label: {
                    Image(systemName: appState.focusService.isRunning ? "brain.head.profile.fill" : "brain.head.profile")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(appState.focusService.isRunning ? accentRed : .secondary)
                        .frame(width: 26, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Focus Timer")

                headerButton(icon: calendarCollapsed ? "chevron.down" : "chevron.up", help: "Toggle Calendar") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        calendarCollapsed.toggle()
                    }
                }
                headerButton(icon: "gearshape", help: "Settings ⌘,") {
                    NotificationCenter.default.post(name: .dismissOverlays, object: nil)
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

            // Carousel: events count + birthdays (fixed height to prevent layout shift)
            let lines = greetingLines
            if !lines.isEmpty {
                ZStack(alignment: .leading) {
                    // Invisible spacer to hold max height
                    Text("Placeholder")
                        .font(.system(size: 12))
                        .opacity(0)

                    lines[greetingIndex % lines.count]
                        .id(greetingIndex)
                }
                .clipped()
                .onAppear { startCarousel(count: lines.count) }
                .animation(.easeInOut(duration: 0.3), value: greetingIndex)

                if hasUpcomingEvents {
                    fatigueMeter
                }
            }

            // Smart nudge
            if let nudge = smartNudge {
                HStack(spacing: 5) {
                    Image(systemName: nudge.icon)
                        .font(.system(size: 9))
                        .foregroundStyle(nudge.color.opacity(0.7))
                    Text(nudge.text)
                        .font(.system(size: 10))
                        .foregroundStyle(nudge.color.opacity(0.6))
                }
                .padding(.top, 2)
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

    // MARK: - Greeting Carousel

    @ViewBuilder
    private var greetingLines: [AnyView] {
        var lines: [AnyView] = []

        // Line 0: event count or all clear
        if hasUpcomingEvents {
            lines.append(AnyView(
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
            ))
        } else {
            lines.append(AnyView(
                Text(allClearMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            ))
        }

        // Birthday lines
        for bday in upcomingBirthdays {
            lines.append(AnyView(
                HStack(spacing: 0) {
                    Text(bday.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("'s birthday")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    if !bday.isToday {
                        Text(" \(bday.dayLabel.lowercased()).")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(" is today!")
                            .font(.system(size: 12))
                            .foregroundStyle(accentRed)
                    }
                }
            ))
        }

        return lines
    }

    private struct UpcomingBirthday {
        let name: String
        let dayLabel: String
        let isToday: Bool
    }

    private var upcomingBirthdays: [UpcomingBirthday] {
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        guard let endDate = cal.date(byAdding: .day, value: 7, to: startOfToday) else { return [] }

        let allDayEvents = appState.calendarService.fetchAllDayEvents(
            from: startOfToday,
            to: endDate,
            disabledCalendarIds: appState.settings.disabledCalendarIds
        )

        return allDayEvents
            .filter { $0.calendarTitle.lowercased().contains("birthday") || $0.title.lowercased().contains("birthday") }
            .prefix(3)
            .map { event in
                let name = cleanBirthdayName(event.title)
                let isToday = cal.isDateInToday(event.startDate)
                let label: String
                if isToday { label = "today" }
                else if cal.isDateInTomorrow(event.startDate) { label = "tomorrow" }
                else {
                    let f = DateFormatter(); f.dateFormat = "EEEE"
                    label = "on \(f.string(from: event.startDate))"
                }
                return UpcomingBirthday(name: name, dayLabel: label, isToday: isToday)
            }
    }

    private func cleanBirthdayName(_ title: String) -> String {
        var name = title
        let patterns = [#"'s \d+\w* Birthday"#, #"'s \d+\w*"#, #"'s Birthday"#, #"'s birthday"#, #" \d+\w* Birthday"#, #" Birthday"#, #" birthday"#]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                name = regex.stringByReplacingMatches(in: name, range: NSRange(name.startIndex..., in: name), withTemplate: "")
            }
        }
        return name.trimmingCharacters(in: .whitespaces)
    }

    private func startCarousel(count: Int) {
        guard count > 1 else { return }
        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            Task { @MainActor in
                greetingIndex += 1
            }
        }
    }

    // MARK: - Fatigue Meter

    private var totalMeetingMinutes: Int {
        appState.todayEvents.reduce(0) { $0 + $1.durationMinutes }
    }

    private var fatigueLevel: (color: Color, label: String) {
        let hours = Double(totalMeetingMinutes) / 60.0
        if hours >= 6 { return (.red, "Heavy day") }
        if hours >= 4 { return (.orange, "Busy") }
        if hours >= 2 { return (.yellow, "Moderate") }
        return (.green, "Light")
    }

    private var fatigueMeter: some View {
        let total = totalMeetingMinutes
        let maxMins = 8 * 60 // 8 hour workday
        let progress = min(Double(total) / Double(maxMins), 1.0)
        let level = fatigueLevel
        let hours = total / 60
        let mins = total % 60

        return HStack(spacing: 6) {
            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(level.color.opacity(0.5))
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)

            // Label
            Text(hours > 0 ? "\(hours)h\(mins > 0 ? " \(mins)m" : "") in meetings" : "\(mins)m in meetings")
                .font(.system(size: 9))
                .foregroundStyle(level.color.opacity(0.6))
                .fixedSize()
        }
        .padding(.top, 4)
    }

    // MARK: - Smart Nudges

    private struct Nudge {
        let icon: String
        let text: String
        let color: Color
    }

    private var smartNudge: Nudge? {
        let events = appState.todayEvents.filter { $0.endDate > Date() }

        // Back-to-back detection
        let backToBack = countBackToBack(events)
        if backToBack >= 3 {
            return Nudge(
                icon: "exclamationmark.triangle",
                text: "\(backToBack) back-to-back meetings — block time for a break",
                color: .orange
            )
        }

        // Heavy day warning
        let hours = Double(totalMeetingMinutes) / 60.0
        if hours >= 6 {
            return Nudge(
                icon: "battery.25percent",
                text: "Over 6h of meetings today — pace yourself",
                color: .red
            )
        }

        // Upcoming prep suggestion
        if let next = appState.nextEvent {
            let minsUntil = Int(next.startDate.timeIntervalSinceNow / 60)
            if minsUntil > 5 && minsUntil <= 15 {
                return Nudge(
                    icon: "lightbulb",
                    text: "\(minsUntil)m until \(String(next.title.prefix(15))) — time to prep",
                    color: accentRed
                )
            }
        }

        return nil
    }

    private func countBackToBack(_ events: [CalendarEvent]) -> Int {
        guard events.count > 1 else { return 0 }
        var streak = 1
        var maxStreak = 1
        for i in 1..<events.count {
            let gap = events[i].startDate.timeIntervalSince(events[i-1].endDate)
            if gap < 5 * 60 { // less than 5 min gap = back-to-back
                streak += 1
                maxStreak = max(maxStreak, streak)
            } else {
                streak = 1
            }
        }
        return maxStreak
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
        if hour >= 20 || hour < 5 {
            // Night — deep indigo/navy
            return [
                .init(color: Color(red: 0.08, green: 0.08, blue: 0.22).opacity(0.9), location: 0),
                .init(color: Color(red: 0.06, green: 0.06, blue: 0.16).opacity(0.5), location: 0.35),
                .init(color: Color(red: 0.05, green: 0.05, blue: 0.10).opacity(0.2), location: 0.6),
                .init(color: .clear, location: 1.0)
            ]
        } else if hour >= 5 && hour < 8 {
            // Dawn — soft pink/orange horizon
            return [
                .init(color: Color(red: 0.35, green: 0.15, blue: 0.18).opacity(0.8), location: 0),
                .init(color: Color(red: 0.30, green: 0.18, blue: 0.10).opacity(0.4), location: 0.35),
                .init(color: Color(red: 0.20, green: 0.12, blue: 0.06).opacity(0.15), location: 0.6),
                .init(color: .clear, location: 1.0)
            ]
        } else if hour >= 8 && hour < 12 {
            // Morning — warm golden
            return [
                .init(color: Color(red: 0.32, green: 0.24, blue: 0.08).opacity(0.7), location: 0),
                .init(color: Color(red: 0.24, green: 0.18, blue: 0.06).opacity(0.35), location: 0.35),
                .init(color: Color(red: 0.16, green: 0.12, blue: 0.04).opacity(0.12), location: 0.6),
                .init(color: .clear, location: 1.0)
            ]
        } else if hour >= 12 && hour < 17 {
            // Afternoon — warm amber
            return [
                .init(color: Color(red: 0.30, green: 0.20, blue: 0.08).opacity(0.7), location: 0),
                .init(color: Color(red: 0.22, green: 0.15, blue: 0.06).opacity(0.35), location: 0.35),
                .init(color: Color(red: 0.14, green: 0.10, blue: 0.04).opacity(0.12), location: 0.6),
                .init(color: .clear, location: 1.0)
            ]
        } else {
            // Evening — dusky purple/blue
            return [
                .init(color: Color(red: 0.14, green: 0.10, blue: 0.24).opacity(0.85), location: 0),
                .init(color: Color(red: 0.10, green: 0.08, blue: 0.18).opacity(0.4), location: 0.35),
                .init(color: Color(red: 0.07, green: 0.06, blue: 0.12).opacity(0.15), location: 0.6),
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
            .font(.system(size: 12.5, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.35))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
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
            let fmt = DateFormatter(); fmt.dateFormat = appState.settings.use24HourTime ? "HH:mm" : "h:mma"; fmt.timeZone = tz
            let t = String(fmt.string(from: Date()).lowercased().dropLast(1))
            return "\(icon) \(city) \(t)"
        }.joined(separator: "  ·  ")
    }

    // MARK: - Actions

    private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
}

