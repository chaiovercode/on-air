import Collaboration
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Palette

private enum P {
    static let bg = Color(red: 0.071, green: 0.063, blue: 0.043)
    static let accent = Color(red: 0.9, green: 0.25, blue: 0.2)
    static let divider = Color.white.opacity(0.07)
    static let sectionTitle = Color.white.opacity(0.45)
    static let rowBg = Color.white.opacity(0.035)
    static let rowBorder = Color.white.opacity(0.05)
    static let text1 = Color.white.opacity(0.85)
    static let text2 = Color.white.opacity(0.45)
    static let text3 = Color.white.opacity(0.25)
}

// MARK: - Always-on Toggle Style

private struct AlwaysOnToggleStyle: ToggleStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            RoundedRectangle(cornerRadius: 12)
                .fill(configuration.isOn ? color : Color.white.opacity(0.1))
                .frame(width: 38, height: 22)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .frame(width: 18, height: 18)
                        .padding(2)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                }
                .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { configuration.isOn.toggle() } }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {

    @ObservedObject var appState: AppState
    @ObservedObject var settings: UserSettings

    enum Tab: String, CaseIterable {
        case general = "General"
        case display = "Display"
        case calendars = "Calendars"
        case stats = "Stats"
        case about = "About"

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .display: return "paintbrush.pointed"
            case .calendars: return "calendar"
            case .stats: return "chart.bar"
            case .about: return "info.circle"
            }
        }
    }

    @State private var selectedTab: Tab = .general
    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 28)

            // Tab bar
            HStack(spacing: 4) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button { selectedTab = tab } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 10.5, weight: .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(selectedTab == tab ? Color(hex: settings.accentColorHex) : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selectedTab == tab ? Color(hex: settings.accentColorHex).opacity(0.1) : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(selectedTab == tab ? Color(hex: settings.accentColorHex).opacity(0.25) : .clear, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 10)

            P.divider.frame(height: 0.5)

            // Two-column layout
            HStack(spacing: 0) {
                // Left: settings content
                Group {
                    switch selectedTab {
                    case .general: generalTab
                    case .display: displayTab
                    case .calendars: calendarsTab
                    case .stats: statsTab
                    case .about: aboutTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Right: live preview (hidden for stats/about)
                if selectedTab == .display || selectedTab == .calendars {
                    P.divider.frame(width: 0.5)
                    previewPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            // Footer
            P.divider.frame(height: 0.5)
            HStack {
                Text("OnAir v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(P.text3)
                Spacer()
                Text("Changes apply instantly")
                    .font(.system(size: 10))
                    .foregroundStyle(P.text3)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .frame(width: 880, height: 700)
        .background(P.bg)
    }

    // MARK: - Preview Panel

    private var previewPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(P.text2)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            P.divider.frame(height: 0.5)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    // Live popover
                    PopoverView(appState: appState)
                        .frame(width: 300, height: 700)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
                        .scaleEffect(0.82)
                        .frame(width: 300 * 0.82, height: 700 * 0.82)
                        .allowsHitTesting(false)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Section("Startup") {
                    iconRow("arrow.right.circle", "Launch at login", sub: "Open OnAir when you start your Mac") {
                        Toggle("", isOn: Binding(
                            get: { settings.launchAtLogin },
                            set: { v in settings.launchAtLogin = v; updateLoginItem(enabled: v) }
                        )).toggleStyle(AlwaysOnToggleStyle(color: Color(hex: settings.accentColorHex)))
                    }
                }

                Section("Countdown") {
                    iconRow("timer", "Lead time", sub: "How early the countdown sound starts") {
                        Picker("", selection: $settings.leadTimeSeconds) {
                            ForEach(UserSettings.LeadTimePreset.allCases, id: \.rawValue) { p in
                                Text(p.displayName).tag(p.seconds)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 130)
                    }
                    iconRow("speaker.wave.2", "Volume", sub: nil) {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.fill").font(.system(size: 9)).foregroundStyle(P.text3)
                            Slider(value: $settings.volume, in: 0...1)
                                .frame(width: 120)
                                .tint(Color(hex: settings.accentColorHex))
                                .onChange(of: settings.volume) { v in appState.countdownPlayer.updateVolume(Float(v)) }
                            Image(systemName: "speaker.wave.3.fill").font(.system(size: 9)).foregroundStyle(P.text3)
                        }
                    }
                    iconRow("bell.badge", "Wrap-up alert", sub: "Notify before your current meeting ends") {
                        Picker("", selection: $settings.wrapUpMinutes) {
                            Text("Off").tag(0)
                            Text("1 min").tag(1)
                            Text("2 min").tag(2)
                            Text("3 min").tag(3)
                            Text("5 min").tag(5)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                    iconRow("music.note", "Sound", sub: nil) {
                        HStack(spacing: 6) {
                            Text(soundLabel)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(P.text2)
                                .lineLimit(1)
                                .frame(maxWidth: 100, alignment: .trailing)
                            Pill("Change…") { selectSoundFile() }
                            Pill("Test") {
                                appState.countdownPlayer.playTestSound(customPath: settings.customSoundPath, volume: Float(settings.volume))
                            }
                        }
                    }
                }

                Section("Data") {
                    iconRow("chart.bar", "Track meeting stats", sub: "Record attendance for analytics") {
                        Toggle("", isOn: $settings.trackStats).toggleStyle(AlwaysOnToggleStyle(color: Color(hex: settings.accentColorHex)))
                    }
                    HStack(spacing: 8) {
                        Spacer()
                        Button {
                            showClearConfirm = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                Text("Clear all stats")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.red.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(.red.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(.red.opacity(0.12), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .alert("Clear all meeting stats?", isPresented: $showClearConfirm) {
                        Button("Clear", role: .destructive) { appState.statsService.clearAll() }
                        Button("Cancel", role: .cancel) {}
                    } message: { Text("This cannot be undone.") }
                }

                Section("Commute") {
                    iconRow("car.fill", "Show commute", sub: "Display commute blocks in Today timeline") {
                        Toggle("", isOn: $settings.showCommute)
                            .toggleStyle(AlwaysOnToggleStyle(color: Color(hex: settings.accentColorHex)))
                    }

                    if settings.showCommute {
                        // Morning commute
                        iconRow("sunrise.fill", "Morning departure", sub: nil) {
                            HStack(spacing: 4) {
                                commuteTimePicker(hour: $settings.morningCommuteHour, minute: $settings.morningCommuteMinute)
                            }
                        }

                        // Evening commute
                        iconRow("sunset.fill", "Evening departure", sub: nil) {
                            HStack(spacing: 4) {
                                commuteTimePicker(hour: $settings.eveningCommuteHour, minute: $settings.eveningCommuteMinute)
                            }
                        }

                        // Duration
                        iconRow("clock.arrow.circlepath", "Duration", sub: nil) {
                            let durations = [(15,"15m"),(30,"30m"),(45,"45m"),(60,"1h"),(75,"1h 15m"),(90,"1h 30m")]
                            let current = durations.first { $0.0 == settings.commuteDurationMinutes }?.1 ?? "30m"
                            Menu {
                                ForEach(durations, id: \.0) { val, label in
                                    Button(label) { settings.commuteDurationMinutes = val }
                                }
                            } label: {
                                Text(current)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(P.text1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(.white.opacity(0.06))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        // Day pills
                        HStack(spacing: 4) {
                            let dayLabels = [(2,"M"),(3,"T"),(4,"W"),(5,"T"),(6,"F"),(7,"S"),(1,"S")]
                            ForEach(dayLabels, id: \.0) { weekday, label in
                                Button {
                                    settings.toggleCommuteDay(weekday)
                                } label: {
                                    Text(label)
                                        .font(.system(size: 11, weight: settings.isCommuteDay(weekday) ? .bold : .regular))
                                        .foregroundStyle(settings.isCommuteDay(weekday) ? .white : P.text3)
                                        .frame(width: 28, height: 28)
                                        .background(
                                            Circle()
                                                .fill(settings.isCommuteDay(weekday) ? Color(hex: settings.accentColorHex).opacity(0.6) : .white.opacity(0.04))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 8)
        }
    }

    private func commuteTimePicker(hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 3) {
            Menu {
                ForEach(5..<23, id: \.self) { h in
                    Button(String(format: "%02d", h)) { hour.wrappedValue = h }
                }
            } label: {
                Text(String(format: "%02d", hour.wrappedValue))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(P.text1)
                    .frame(width: 32, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)

            Text(":")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(P.text3)

            Menu {
                ForEach([0, 15, 30, 45], id: \.self) { m in
                    Button(String(format: "%02d", m)) { minute.wrappedValue = m }
                }
            } label: {
                Text(String(format: "%02d", minute.wrappedValue))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(P.text1)
                    .frame(width: 32, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func iconRow<C: View>(_ icon: String, _ label: String, sub: String?, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: settings.accentColorHex).opacity(0.7))
                .frame(width: 20, alignment: .center)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(P.text1)
                if let sub {
                    Text(sub)
                        .font(.system(size: 10))
                        .foregroundStyle(P.text3)
                        .lineLimit(1)
                }
            }
            Spacer()
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            P.divider.frame(height: 0.5).padding(.horizontal, 16)
        }
    }

    // MARK: - Display Tab

    private let accentPresets: [(name: String, hex: String)] = [
        ("Coral",    "#FF6B6B"),
        ("Tangerine","#FF8C42"),
        ("Lemon",    "#FFD93D"),
        ("Mint",     "#38E8A0"),
        ("Electric", "#4DA6FF"),
        ("Violet",   "#B266FF"),
        ("Fuchsia",  "#FF4DA6"),
    ]

    @State private var customHex = ""

    private var displayTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Section("Accent Color") {
                    VStack(spacing: 0) {
                        // Swatches
                        HStack(spacing: 0) {
                            ForEach(accentPresets, id: \.hex) { preset in
                                Button {
                                    settings.accentColorHex = preset.hex
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: preset.hex))
                                            .frame(width: 28, height: 28)
                                        if settings.accentColorHex.uppercased() == preset.hex.uppercased() {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)

                        P.divider.frame(height: 0.5).padding(.horizontal, 16)

                        // Custom hex
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(hex: settings.accentColorHex))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                                )

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Custom")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(P.text1)
                                Text("Enter hex code")
                                    .font(.system(size: 10))
                                    .foregroundStyle(P.text3)
                            }

                            Spacer()

                            TextField("#FF9500", text: $customHex)
                                .onSubmit {
                                    let clean = customHex.hasPrefix("#") ? customHex : "#\(customHex)"
                                    if clean.count == 7 { settings.accentColorHex = clean }
                                }
                                .onAppear { customHex = settings.accentColorHex }
                                .onChange(of: settings.accentColorHex) { val in customHex = val }
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(P.text1)
                            .frame(width: 80)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(.white.opacity(0.07), lineWidth: 0.5)
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }

                Section("Time & Display") {
                    iconRow("clock", "Time format", sub: nil) {
                        HStack(spacing: 0) {
                            Button { settings.use24HourTime = false } label: {
                                Text("12h")
                                    .font(.system(size: 12, weight: settings.use24HourTime ? .regular : .bold))
                                    .foregroundStyle(settings.use24HourTime ? P.text2 : .white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(settings.use24HourTime ? .clear : Color(hex: settings.accentColorHex).opacity(0.25))
                                    )
                            }
                            .buttonStyle(.plain)
                            Button { settings.use24HourTime = true } label: {
                                Text("24h")
                                    .font(.system(size: 12, weight: settings.use24HourTime ? .bold : .regular))
                                    .foregroundStyle(settings.use24HourTime ? .white : P.text2)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(settings.use24HourTime ? Color(hex: settings.accentColorHex).opacity(0.25) : .clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
                        )
                    }
                    iconRow("chart.line.uptrend.xyaxis", "Year progress bar", sub: "Show how far through the year we are") {
                        Toggle("", isOn: $settings.showYearProgress).toggleStyle(AlwaysOnToggleStyle(color: Color(hex: settings.accentColorHex)))
                    }
                    iconRow("square.grid.3x3.fill", "Calendar heatmap", sub: "Color days by meeting density") {
                        Toggle("", isOn: $settings.showCalendarHeatmap).toggleStyle(AlwaysOnToggleStyle(color: Color(hex: settings.accentColorHex)))
                    }
                    iconRow("eye", "Show past meetings", sub: "Show today's ended events in the agenda") {
                        Toggle("", isOn: $settings.showPastMeetings).toggleStyle(AlwaysOnToggleStyle(color: Color(hex: settings.accentColorHex)))
                    }
                    iconRow("calendar.day.timeline.left", "Hide empty days", sub: "Hides days with no events from the agenda") {
                        Toggle("", isOn: $settings.hideEmptyDays).toggleStyle(AlwaysOnToggleStyle(color: Color(hex: settings.accentColorHex)))
                    }
                }

                Section("World Clock") {
                    ForEach(settings.worldClockIds, id: \.self) { tzId in
                        if let tz = TimeZone(identifier: tzId) {
                            iconRow("globe", cityName(tzId), sub: nil) {
                                Text(fmtTime(tz))
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(P.text2)
                                Button {
                                    settings.worldClockIds.removeAll { $0 == tzId }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(P.text3)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if settings.worldClockIds.count < 4 {
                        WorldClockAddRow(settings: settings)
                    }
                }
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, 24).padding(.vertical, 8)
        }
    }

    // MARK: - Calendars Tab

    private var calendarsTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Help — compact collapsible
                Section("Setup") {
                    iconRow("questionmark.circle", "Where are my events?", sub: "OnAir reads from macOS Calendar. Add accounts in System Settings.") {
                        Button {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Internet-Accounts") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Text("Open")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color(hex: settings.accentColorHex).opacity(0.7))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Options") {
                    iconRow("calendar.badge.plus", "Focus block calendar", sub: "Where focus blocks are created") {
                        let cals = appState.calendarService.availableCalendars
                        let current = cals.first { $0.id == settings.focusCalendarId }?.title ?? "Default"
                        Menu {
                            Button("Default") { settings.focusCalendarId = nil }
                            Divider()
                            ForEach(cals, id: \.id) { cal in
                                Button(cal.title) { settings.focusCalendarId = cal.id }
                            }
                        } label: {
                            Text(current)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(P.text1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .strokeBorder(.white.opacity(0.07), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    iconRow("sparkles", "Long weekends", sub: "Highlight extended weekends around holidays") {
                        Toggle("", isOn: $settings.showLongWeekends)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .tint(Color(hex: settings.accentColorHex))
                    }

                    if settings.showLongWeekends && !appState.calendarService.availableCalendars.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 9))
                                .foregroundStyle(P.text3)
                            Text("Mark holiday calendars below to detect long weekends")
                                .font(.system(size: 10))
                                .foregroundStyle(P.text3)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }

                    if settings.showLongWeekends && !settings.holidayCalendarIds.isEmpty {
                        upcomingHolidaysList
                    }
                }

                if !appState.calendarService.availableCalendars.isEmpty {
                    Section("Show Calendars") {
                        // Header: count + All/None
                        HStack {
                            let total = appState.calendarService.availableCalendars.count
                            let enabled = appState.calendarService.availableCalendars.filter { settings.isCalendarEnabled($0.id) }.count
                            Text("\(enabled) of \(total) selected")
                                .font(.system(size: 12))
                                .foregroundStyle(P.text3)
                            Spacer()
                            Button("All") {
                                settings.disabledCalendarIds = []
                                appState.refreshEvents()
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: settings.accentColorHex))
                            .buttonStyle(.plain)

                            Text("·").foregroundStyle(P.text3)

                            Button("None") {
                                let allIds = Set(appState.calendarService.availableCalendars.map(\.id))
                                settings.disabledCalendarIds = allIds
                                appState.refreshEvents()
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(P.text2)
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            P.divider.frame(height: 0.5).padding(.horizontal, 16)
                        }

                        // Calendar list
                        ForEach(appState.calendarService.availableCalendars, id: \.id) { cal in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(hex: cal.colorHex))
                                    .frame(width: 10, height: 10)
                                Text(cal.title)
                                    .font(.system(size: 13))
                                    .foregroundStyle(settings.isCalendarEnabled(cal.id) ? P.text1 : P.text3)
                                    .lineLimit(1)
                                Spacer()

                                // Holiday chip (when long weekends is on)
                                if settings.showLongWeekends {
                                    Button {
                                        settings.toggleHolidayCalendar(cal.id)
                                    } label: {
                                        HStack(spacing: 3) {
                                            Image(systemName: settings.isHolidayCalendar(cal.id) ? "diamond.fill" : "diamond")
                                                .font(.system(size: 6))
                                            Text("Holiday")
                                                .font(.system(size: 10, weight: .medium))
                                        }
                                        .foregroundStyle(settings.isHolidayCalendar(cal.id) ? Color(hex: settings.accentColorHex) : P.text3)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .fill(settings.isHolidayCalendar(cal.id) ? Color(hex: settings.accentColorHex).opacity(0.12) : .clear)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .strokeBorder(settings.isHolidayCalendar(cal.id) ? Color(hex: settings.accentColorHex).opacity(0.3) : P.text3.opacity(0.3), lineWidth: 0.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }

                                Toggle("", isOn: Binding(
                                    get: { settings.isCalendarEnabled(cal.id) },
                                    set: { _ in settings.toggleCalendar(cal.id); appState.refreshEvents() }
                                )).toggleStyle(AlwaysOnToggleStyle(color: Color(hex: settings.accentColorHex)))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .overlay(alignment: .bottom) {
                                P.divider.frame(height: 0.5).padding(.horizontal, 16)
                            }
                        }
                    }
                } else {
                    // Empty state
                    VStack(spacing: 16) {
                        Spacer().frame(height: 80)
                        ZStack {
                            Circle()
                                .fill(Color(hex: settings.accentColorHex).opacity(0.08))
                                .frame(width: 80, height: 80)
                                .blur(radius: 20)
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(P.text3)
                        }
                        Text("No calendars found")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(P.text1)
                        Text("Grant calendar access to see\nyour calendars here.")
                            .font(.system(size: 12))
                            .foregroundStyle(P.text2)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, 24).padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Upcoming Holidays List

    private var upcomingHolidaysList: some View {
        let cal = Calendar.current
        let now = Date()
        let start = cal.startOfDay(for: now)
        guard let end = cal.date(byAdding: .month, value: 3, to: start) else {
            return AnyView(EmptyView())
        }
        let allDay = appState.calendarService.fetchAllDayEvents(
            from: start, to: end, disabledCalendarIds: []
        )
        let holidayIds = settings.holidayCalendarIds
        let holidays = allDay
            .filter { holidayIds.contains($0.calendarId) }
            .sorted { $0.startDate < $1.startDate }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "MMM d, EEE"

        if holidays.isEmpty {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                Text("UPCOMING HOLIDAYS")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(P.text3)
                    .tracking(1.2)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                ForEach(holidays, id: \.id) { holiday in
                    let dateStr = formatter.string(from: cal.startOfDay(for: holiday.startDate))
                    let dismissed = settings.isHolidayDismissed(dateStr)

                    HStack(spacing: 10) {
                        Button {
                            settings.toggleHolidayDismissed(dateStr)
                        } label: {
                            Image(systemName: dismissed ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(dismissed ? P.text3 : Color(hex: settings.accentColorHex))
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(holiday.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(dismissed ? P.text3 : P.text1)
                                .strikethrough(dismissed, color: P.text3)
                            Text(dateFmt.string(from: holiday.startDate))
                                .font(.system(size: 10))
                                .foregroundStyle(P.text3)
                        }

                        Spacer()

                        if dismissed {
                            Text("skipped")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(P.text3)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .overlay(alignment: .bottom) {
                        P.divider.frame(height: 0.5).padding(.horizontal, 16)
                    }
                }
            }
        )
    }

    // MARK: - Stats Tab (settings-native)

    private var accentColor: Color { Color(hex: settings.accentColorHex) }

    private var statsTab: some View {
        let stats = appState.statsService
        let focus = appState.focusService
        let hasData = !stats.records.isEmpty || focus.totalSessions > 0
        let amber = Color(red: 1.0, green: 0.6, blue: 0.2)
        let blue = Color(red: 0.35, green: 0.55, blue: 1.0)

        return ScrollView(.vertical, showsIndicators: false) {
            if !hasData {
                VStack(spacing: 16) {
                    Spacer().frame(height: 80)
                    ZStack {
                        Circle().fill(accentColor.opacity(0.08)).frame(width: 80, height: 80).blur(radius: 20)
                        Image(systemName: "chart.bar.xaxis.ascending")
                            .font(.system(size: 28, weight: .light)).foregroundStyle(P.text3)
                    }
                    Text("No stats yet").font(.system(size: 15, weight: .semibold)).foregroundStyle(P.text1)
                    Text("Attend a meeting or start a\nfocus session to see stats.")
                        .font(.system(size: 12)).foregroundStyle(P.text2)
                        .multilineTextAlignment(.center).lineSpacing(3)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 16) {

                    // MARK: Hero Cards
                    HStack(spacing: 12) {
                        heroCard(
                            value: "\(stats.meetingsThisWeek)",
                            label: "THIS WEEK",
                            icon: "flame.fill",
                            color: accentColor
                        )
                        heroCard(
                            value: stats.hoursThisWeekDisplay,
                            label: "HOURS",
                            icon: "clock.fill",
                            color: amber
                        )
                        if focus.totalSessions > 0 {
                            heroCard(
                                value: "\(Int(focus.completionRate * 100))%",
                                label: "FOCUS",
                                icon: "brain.head.profile",
                                color: .green
                            )
                        } else {
                            heroCard(
                                value: stats.avgDurationDisplay,
                                label: "AVG LENGTH",
                                icon: "timer",
                                color: blue
                            )
                        }
                    }
                    .padding(.top, 16)

                    // MARK: Week Strip
                    if !stats.records.isEmpty {
                        dataTile(title: "This Week", icon: "calendar") {
                            let dayData = statsWeekDayData
                            let maxCount = max(dayData.map(\.count).max() ?? 1, 1)

                            HStack(spacing: 6) {
                                ForEach(Array(dayData.enumerated()), id: \.offset) { _, day in
                                    VStack(spacing: 5) {
                                        // Count label
                                        Text(day.count > 0 ? "\(day.count)" : "")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundStyle(P.text2)
                                            .frame(height: 14)

                                        // Bar
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(day.count > 0 ? accentColor : .white.opacity(0.04))
                                            .frame(height: day.count > 0
                                                ? max(CGFloat(day.count) / CGFloat(maxCount) * 52, 8)
                                                : 3)
                                            .frame(maxHeight: 52, alignment: .bottom)

                                        // Day label
                                        Text(day.initial)
                                            .font(.system(size: 10, weight: day.isToday ? .bold : .medium))
                                            .foregroundStyle(day.isToday ? P.text1 : P.text3)
                                            .frame(width: 22, height: 22)
                                            .background(
                                                Circle()
                                                    .fill(day.isToday ? .white.opacity(0.06) : .clear)
                                            )
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }

                    // MARK: Focus Summary
                    if focus.totalSessions > 0 {
                        dataTile(title: "Focus", icon: "brain.head.profile") {
                            HStack(spacing: 0) {
                                focusTile(value: "\(focusSessionsThisWeek)", label: "Sessions", sub: "this week", color: .green)
                                    .frame(maxWidth: .infinity)
                                tileVerticalDivider
                                focusTile(value: formatMinutes(focus.weekFocusMinutes), label: "Time", sub: "this week", color: .green)
                                    .frame(maxWidth: .infinity)
                                tileVerticalDivider
                                focusTile(value: "\(focus.todayFocusMinutes)m", label: "Today", sub: "focused", color: .green)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    // MARK: Breakdown
                    HStack(alignment: .top, spacing: 12) {
                        if !stats.peakHours.isEmpty {
                            dataTile(title: "Peak Hours", icon: "clock.fill") {
                                VStack(spacing: 10) {
                                    ForEach(stats.peakHours.prefix(4), id: \.hour) { item in
                                        statsBreakdownRow(
                                            label: item.hour,
                                            percentage: item.percentage,
                                            color: amber
                                        )
                                    }
                                }
                            }
                        }

                        if !stats.platformBreakdown.isEmpty {
                            dataTile(title: "Platforms", icon: "video.fill") {
                                VStack(spacing: 10) {
                                    ForEach(stats.platformBreakdown, id: \.platform) { item in
                                        statsBreakdownRow(
                                            label: item.platform,
                                            percentage: item.percentage,
                                            color: blue
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // MARK: Top People + Recurring (side by side)
                    HStack(alignment: .top, spacing: 12) {
                        if !stats.topAttendees.isEmpty {
                            let maxAttendeeCount = max(stats.topAttendees.first?.count ?? 1, 1)
                            dataTile(title: "Top People", icon: "person.2.fill") {
                                VStack(spacing: 10) {
                                    ForEach(Array(stats.topAttendees.enumerated()), id: \.element.name) { i, person in
                                        HStack(spacing: 10) {
                                            ZStack {
                                                Circle()
                                                    .fill(i == 0 ? accentColor.opacity(0.15) : .white.opacity(0.04))
                                                    .frame(width: 28, height: 28)
                                                Text(String(person.name.prefix(1)).uppercased())
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(i == 0 ? accentColor : P.text3)
                                            }

                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Text(person.name)
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundStyle(P.text1)
                                                        .lineLimit(1)
                                                    Spacer()
                                                    Text("\(person.count)\u{00D7}")
                                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                                        .foregroundStyle(P.text3)
                                                        .monospacedDigit()
                                                }
                                                GeometryReader { geo in
                                                    ZStack(alignment: .leading) {
                                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                            .fill(.white.opacity(0.04))
                                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                            .fill(accentColor)
                                                            .frame(width: max(geo.size.width * CGFloat(person.count) / CGFloat(maxAttendeeCount), 6))
                                                    }
                                                }
                                                .frame(height: 4)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Recurring
                        if !stats.topMeetings.isEmpty {
                            dataTile(title: "Recurring", icon: "arrow.2.squarepath") {
                                VStack(spacing: 0) {
                                    ForEach(Array(stats.topMeetings.enumerated()), id: \.element.title) { i, item in
                                        HStack(spacing: 10) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                    .fill(i == 0 ? accentColor.opacity(0.15) : .white.opacity(0.04))
                                                    .frame(width: 24, height: 24)
                                                Text("\(i + 1)")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(i == 0 ? accentColor : P.text3)
                                            }

                                            Text(item.title)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(P.text1)
                                                .lineLimit(1)

                                            Spacer()

                                            Text("\(item.count)\u{00D7}")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(i == 0 ? accentColor : P.text3)
                                                .monospacedDigit()
                                        }
                                        .padding(.vertical, 8)

                                        if i < stats.topMeetings.count - 1 {
                                            P.divider.frame(height: 0.5)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Hero Card

    private func heroCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(color.opacity(0.6))
                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(P.text3)
                .tracking(1.5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.03))
        )
        .overlay(alignment: .top) {
            // Solid accent line at top
            UnevenRoundedRectangle(
                topLeadingRadius: 14, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 14
            )
            .fill(color.opacity(0.5))
            .frame(height: 2)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.05), lineWidth: 0.5)
        )
    }

    // MARK: - Stats Breakdown Row

    private func statsBreakdownRow(label: String, percentage: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(P.text1)
                    .lineLimit(1)
                Spacer()
                Text("\(Int(percentage))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(P.text3)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(.white.opacity(0.04))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color)
                        .frame(width: max(geo.size.width * percentage / 100, 6))
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Data Tile

    private func dataTile<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(P.text3)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(P.text2)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.05), lineWidth: 0.5)
        )
    }

    // MARK: - Focus Tile

    private func focusTile(value: String, label: String, sub: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(P.text2)
            Text(sub)
                .font(.system(size: 9))
                .foregroundStyle(P.text3)
        }
        .padding(.vertical, 6)
    }

    private var tileVerticalDivider: some View {
        Rectangle().fill(.white.opacity(0.06)).frame(width: 0.5, height: 36)
    }

    // MARK: - Stats Helpers

    private var focusSessionsThisWeek: Int {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return appState.focusService.sessions.filter { $0.date > weekAgo }.count
    }

    private func formatMinutes(_ mins: Int) -> String {
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(mins)m"
    }

    private struct StatsDayInfo {
        let initial: String
        let count: Int
        let isToday: Bool
    }

    private var statsWeekDayData: [StatsDayInfo] {
        let cal = Calendar.current
        let today = Date()
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: today) else { return [] }

        let initials = ["M", "T", "W", "T", "F", "S", "S"]
        let todayWeekday = cal.component(.weekday, from: today)
        let todayIndex = todayWeekday == 1 ? 6 : todayWeekday - 2

        let weekRecords = appState.statsService.records.filter { $0.date >= weekInterval.start }
        var counts = [Int](repeating: 0, count: 7)
        for record in weekRecords {
            let wd = cal.component(.weekday, from: record.date)
            let index = wd == 1 ? 6 : wd - 2
            counts[index] += 1
        }

        return (0..<7).map { i in
            StatsDayInfo(initial: initials[i], count: counts[i], isToday: i == todayIndex)
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 0) {
            Spacer()

            // App icon with dynamic accent glow
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.6)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 88, height: 88)
                    .shadow(color: accentColor.opacity(0.3), radius: 20, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .topLeading, endPoint: .center))
                            .frame(width: 88, height: 88)
                    )
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .padding(.bottom, 24)

            Text("OnAir")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(P.text1)
                .padding(.bottom, 4)
            Text("Your meetings, always visible.")
                .font(.system(size: 13))
                .foregroundStyle(P.text2)
                .padding(.bottom, 6)
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(P.text3)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.white.opacity(0.04))
                )

            Spacer()

            // User info footer
            P.divider.frame(height: 0.5)
            HStack(spacing: 8) {
                if let img = CBIdentity(name: NSUserName(), authority: .local())?.image {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 18, height: 18)
                        .clipShape(Circle())
                }
                Text(NSFullUserName())
                    .font(.system(size: 11))
                    .foregroundStyle(P.text2)
            }
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var soundLabel: String {
        settings.customSoundPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Default"
    }

    private func cityName(_ tzId: String) -> String {
        tzId.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? tzId
    }

    private func fmtTime(_ tz: TimeZone) -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; f.timeZone = tz
        return f.string(from: Date()).lowercased()
    }

    private func selectSoundFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]; panel.canChooseFiles = true
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        if panel.runModal() == .OK, let url = panel.url {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("OnAir")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent("countdown.\(url.pathExtension)")
            try? FileManager.default.removeItem(at: dest)
            do { try FileManager.default.copyItem(at: url, to: dest); settings.customSoundPath = dest.path; appState.soundWarning = false }
            catch { appState.soundWarning = true }
        }
    }

    private func updateLoginItem(enabled: Bool) {
        if enabled { try? SMAppService.mainApp.register() }
        else { try? SMAppService.mainApp.unregister() }
    }
}

// MARK: - Design System

/// Section title + row group wrapper
private struct Section<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(P.sectionTitle)
                .padding(.top, 22).padding(.bottom, 8)

            VStack(spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(P.rowBg))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(P.rowBorder, lineWidth: 0.5))
        }
    }
}

/// Standard row: label left, controls right
private struct Row<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content
    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label; self.content = content()
    }
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(P.text1)
                .lineLimit(1)
            Spacer()
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            P.divider.frame(height: 0.5).padding(.horizontal, 16)
        }
    }
}

/// Stat overview row with colored value
private struct StatRow: View {
    let label: String; let value: String; let color: Color
    init(_ label: String, value: String, color: Color) {
        self.label = label; self.value = value; self.color = color
    }
    var body: some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(P.text1)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            P.divider.frame(height: 0.5).padding(.horizontal, 16)
        }
    }
}

/// Inline bar indicator for stats
private struct BarIndicator: View {
    let value: Double; let color: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.04))
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.6), color], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(geo.size.width * value / 100, 4))
            }
        }
        .frame(width: 80, height: 6)
    }
}

/// Ghost pill button
private struct Pill: View {
    let label: String; let action: () -> Void
    init(_ label: String, action: @escaping () -> Void) { self.label = label; self.action = action }
    var body: some View {
        Button(action: action) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(P.text2)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
        }.buttonStyle(.plain)
    }
}

/// World clock inline add row
private struct WorldClockAddRow: View {
    @ObservedObject var settings: UserSettings
    @State private var searching = false
    @State private var query = ""

    var body: some View {
        if searching {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 10)).foregroundStyle(P.text3)
                    TextField("Search city…", text: $query).textFieldStyle(.plain).font(.system(size: 13))
                    Button { searching = false; query = "" } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundStyle(P.text3)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)

                if !results.isEmpty {
                    P.divider.frame(height: 0.5).padding(.horizontal, 16)
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(results, id: \.self) { tzId in
                                Button {
                                    settings.worldClockIds.append(tzId); searching = false; query = ""
                                } label: {
                                    Text(tzId.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? tzId)
                                        .font(.system(size: 13)).foregroundStyle(P.text2)
                                        .padding(.horizontal, 16).padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }
                        }
                    }.frame(maxHeight: 120)
                }
            }
        } else {
            HStack {
                Button { searching = true; query = "" } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle").font(.system(size: 13))
                        Text("Add city").font(.system(size: 13))
                    }.foregroundStyle(P.text2)
                }.buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                P.divider.frame(height: 0.5).padding(.horizontal, 16)
            }
        }
    }

    private var results: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers.filter { $0.contains("/") }
        let existing = Set(settings.worldClockIds); let local = TimeZone.current.identifier
        let available = all.filter { $0 != local && !existing.contains($0) }
        if query.isEmpty { return Array(available.prefix(10)) }
        let q = query.lowercased()
        return available.filter { ($0.components(separatedBy: "/").last ?? "").lowercased().contains(q) }.prefix(10).map { $0 }
    }
}
