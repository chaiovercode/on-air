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
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 10.5, weight: .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(selectedTab == tab ? Color(hex: settings.accentColorHex) : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selectedTab == tab ? Color(hex: settings.accentColorHex).opacity(0.1) : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(selectedTab == tab ? Color(hex: settings.accentColorHex).opacity(0.25) : .clear, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.borderless)
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
                    case .stats: StatsTabContent(
                        stats: appState.statsService,
                        focus: appState.focusService,
                        accentColor: accentColor
                    )
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
                    iconRow("speaker.slash", "Mute countdown", sub: "Silence the audio before meetings") {
                        Toggle("", isOn: Binding(
                            get: { !settings.countdownSoundEnabled },
                            set: { settings.countdownSoundEnabled = !$0 }
                        ))
                        .toggleStyle(AlwaysOnToggleStyle(color: accentColor))
                    }
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

                // Booking section disabled
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

    // MARK: - Stats Tab (settings-native)

    private var accentColor: Color { Color(hex: settings.accentColorHex) }

    // Stats tab delegates to isolated StatsTabContent to avoid tick-timer re-renders

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

// MARK: - Stats Tab (Duolingo-inspired, isolated from AppState tick timer)

private enum StatsPeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var startDate: Date {
        let cal = Calendar.current
        switch self {
        case .week:
            return cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        case .month:
            return cal.dateInterval(of: .month, for: Date())?.start ?? Date()
        case .year:
            return cal.dateInterval(of: .year, for: Date())?.start ?? Date()
        }
    }
}

private struct StatsTabContent: View {
    @ObservedObject var stats: StatsService
    @ObservedObject var focus: FocusService
    let accentColor: Color

    @State private var period: StatsPeriod = .week

    private let card = Color.white.opacity(0.035)
    private let cardBorder = Color.white.opacity(0.06)

    private var filtered: [MeetingRecord] {
        stats.records.filter { $0.date >= period.startDate }
    }

    var body: some View {
        let hasData = !stats.records.isEmpty || focus.totalSessions > 0

        ScrollView(.vertical, showsIndicators: false) {
            if !hasData {
                VStack(spacing: 20) {
                    Spacer().frame(height: 60)
                    ZStack {
                        Circle().fill(accentColor.opacity(0.08)).frame(width: 100, height: 100).blur(radius: 30)
                        Image(systemName: "chart.bar.xaxis.ascending")
                            .font(.system(size: 32, weight: .light)).foregroundStyle(P.text3)
                    }
                    Text("No stats yet")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(P.text1)
                    Text("Attend a meeting or start a\nfocus session to get started!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(P.text2)
                        .multilineTextAlignment(.center).lineSpacing(3)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 14) {

                    // MARK: — Period filter
                    HStack(spacing: 4) {
                        ForEach(StatsPeriod.allCases, id: \.self) { p in
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) { period = p }
                            } label: {
                                Text(p.rawValue)
                                    .font(.system(size: 11, weight: period == p ? .bold : .medium))
                                    .foregroundStyle(period == p ? .white : P.text3)
                                    .padding(.horizontal, 12).padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(period == p ? accentColor : .white.opacity(0.04))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.top, 10)

                    // MARK: — Streak hero
                    streakHero

                    // MARK: — Weekly dots
                    if period == .week { weeklyDots }

                    // MARK: — Focus ring (if data)
                    if focus.totalSessions > 0 {
                        focusRing
                    }

                    // MARK: — Contribution graph
                    if !stats.records.isEmpty {
                        HeatmapView(stats: stats, accentColor: accentColor)
                    }

                    // MARK: — Leaderboard
                    if !filteredAttendees.isEmpty {
                        leaderboard
                    }

                    // MARK: — Quick stats row
                    if !filteredPeakHours.isEmpty || !filteredPlatforms.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            if !filteredPeakHours.isEmpty {
                                peakHoursCard.frame(maxHeight: .infinity, alignment: .top)
                            }
                            if !filteredPlatforms.isEmpty {
                                platformsCard.frame(maxHeight: .infinity, alignment: .top)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    // MARK: — Recurring
                    if !filteredRecurring.isEmpty {
                        recurringCard
                    }

                    Spacer().frame(height: 8)
                }
                .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Streak Hero

    private var streakHero: some View {
        let count = filtered.count
        let hours = Double(filtered.reduce(0) { $0 + $1.durationMinutes }) / 60.0
        let avgMins = count > 0 ? filtered.reduce(0) { $0 + $1.durationMinutes } / count : 0
        let label = period == .week ? "this week" : period == .month ? "this month" : "this year"

        return HStack(spacing: 0) {
            // Meetings
            VStack(alignment: .leading, spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(accentColor)
                Text("meetings")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(P.text3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Hours
            VStack(spacing: 4) {
                Text(String(format: "%.1f", hours))
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(P.text1)
                Text("hours")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(P.text3)
            }
            .frame(maxWidth: .infinity)

            // Avg
            VStack(spacing: 4) {
                Text("\(avgMins)m")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(P.text2)
                Text("avg")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(P.text3)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(cardBorder, lineWidth: 0.5))
    }

    // MARK: - Weekly Dots

    private var weeklyDots: some View {
        let dayData = weekDayData
        return HStack(spacing: 0) {
            ForEach(Array(dayData.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 5) {
                    Text(day.initial)
                        .font(.system(size: 10, weight: day.isToday ? .bold : .medium))
                        .foregroundStyle(day.isToday ? P.text1 : P.text3)

                    ZStack {
                        Circle()
                            .fill(day.count > 0 ? accentColor.opacity(day.isToday ? 1 : 0.6) : .white.opacity(0.05))
                            .frame(width: 28, height: 28)
                        if day.count > 0 {
                            Text("\(day.count)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }

                    if day.isToday {
                        Circle().fill(accentColor).frame(width: 3, height: 3)
                    } else {
                        Spacer().frame(height: 3)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(cardBorder, lineWidth: 0.5))
    }

    // MARK: - Focus Ring

    private var focusRing: some View {
        let todayMins = focus.todayFocusMinutes
        let weekMins = focus.weekFocusMinutes
        let goal: Double = 120
        let progress = min(Double(todayMins) / goal, 1.0)
        let rate = Int(focus.completionRate * 100)
        let focusGreen = Color(red: 0.3, green: 0.75, blue: 0.4)

        return HStack(spacing: 14) {
            ZStack {
                Circle().stroke(.white.opacity(0.06), lineWidth: 5).frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(focusGreen, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(todayMins)m")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(focusGreen)
                    Text("today")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(P.text3)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text(formatMinutes(weekMins)).font(.system(size: 14, weight: .heavy)).foregroundStyle(P.text1)
                        Text("this week").font(.system(size: 8, weight: .medium)).foregroundStyle(P.text3)
                    }.frame(maxWidth: .infinity)
                    VStack(spacing: 2) {
                        Text("\(focusSessionsThisWeek)").font(.system(size: 14, weight: .heavy)).foregroundStyle(P.text1)
                        Text("sessions").font(.system(size: 8, weight: .medium)).foregroundStyle(P.text3)
                    }.frame(maxWidth: .infinity)
                    VStack(spacing: 2) {
                        Text("\(rate)%").font(.system(size: 14, weight: .heavy)).foregroundStyle(P.text1)
                        Text("rate").font(.system(size: 8, weight: .medium)).foregroundStyle(P.text3)
                    }.frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(cardBorder, lineWidth: 0.5))
    }

    // MARK: - Leaderboard

    private var leaderboard: some View {
        return sectionCard(title: "TOP PEOPLE", icon: "person.2.fill") {
            ForEach(Array(filteredAttendees.enumerated()), id: \.element.name) { i, person in
                let dn = extractDisplayName(person.name)
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(i == 0 ? accentColor.opacity(0.15) : .white.opacity(0.05))
                            .frame(width: 30, height: 30)
                        Text(String(dn.prefix(1)).uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(i == 0 ? accentColor : P.text2)
                    }
                    Text(dn)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(P.text1).lineLimit(1)
                    Spacer()
                    Text("\(person.count)")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(i == 0 ? accentColor : P.text2).monospacedDigit()
                }
                if i < filteredAttendees.count - 1 { P.divider.frame(height: 0.5) }
            }
        }
    }

    // MARK: - Peak Hours Card

    private var peakHoursCard: some View {
        let amber = Color(red: 0.9, green: 0.65, blue: 0.25)
        return sectionCard(title: "PEAK HOURS", icon: "clock.fill") {
            ForEach(filteredPeakHours.prefix(3), id: \.hour) { item in
                HStack(spacing: 6) {
                    Text(item.hour)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(P.text2)
                        .frame(width: 50, alignment: .leading)
                    barFill(fraction: item.percentage / 100, color: amber)
                    Text("\(Int(item.percentage))%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(P.text3)
                        .frame(width: 24, alignment: .trailing).monospacedDigit()
                }
            }
        }
    }

    // MARK: - Platforms Card

    private var platformsCard: some View {
        let blue = Color(red: 0.4, green: 0.6, blue: 1.0)
        return sectionCard(title: "PLATFORMS", icon: "video.fill") {
            ForEach(Array(filteredPlatforms.enumerated()), id: \.element.platform) { i, item in
                HStack(spacing: 8) {
                    Circle().fill(i == 0 ? blue : P.text3).frame(width: 5, height: 5)
                    Text(item.platform)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(P.text1).lineLimit(1)
                    Spacer()
                    Text("\(item.count)")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(P.text2).monospacedDigit()
                }
            }
        }
    }

    // MARK: - Recurring Card

    private var recurringCard: some View {
        sectionCard(title: "RECURRING", icon: "arrow.2.squarepath") {
            ForEach(Array(filteredRecurring.prefix(4).enumerated()), id: \.element.title) { i, item in
                HStack(spacing: 10) {
                    Text("\(item.count)")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(i == 0 ? accentColor : P.text2)
                        .frame(width: 22).monospacedDigit()
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(P.text1).lineLimit(1)
                    Spacer()
                }
                if i < min(filteredRecurring.count, 4) - 1 { P.divider.frame(height: 0.5) }
            }
        }
    }

    // MARK: - Section Card

    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 9)).foregroundStyle(P.text3)
                Text(title)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(P.text3).tracking(1)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(cardBorder, lineWidth: 0.5))
    }

    // MARK: - Bar Fill

    private func barFill(fraction: CGFloat, color: Color, height: CGFloat = 7) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(.white.opacity(0.04))
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color).frame(width: max(geo.size.width * fraction, 4))
            }
        }
        .frame(height: height)
    }

    // MARK: - Calendar Heatmap

    // MARK: - Filtered Data

    private var filteredAttendees: [(name: String, count: Int)] {
        var counts = [String: Int]()
        for r in filtered { for name in r.attendees { counts[name, default: 0] += 1 } }
        return counts.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }.prefix(3).map { $0 }
    }

    private var filteredPeakHours: [(hour: String, count: Int, percentage: Double)] {
        let cal = Calendar.current
        var counts = [Int: Int]()
        for r in filtered { counts[cal.component(.hour, from: r.startTime), default: 0] += 1 }
        let total = max(filtered.count, 1)
        return counts.map { hour, count in
            let h = hour % 12 == 0 ? 12 : hour % 12
            let p = hour < 12 ? "a" : "p"
            let h2 = (hour + 1) % 12 == 0 ? 12 : (hour + 1) % 12
            let p2 = (hour + 1) < 12 || (hour + 1) == 24 ? "a" : "p"
            return (hour: "\(h)\(p)–\(h2)\(p2)", count: count, percentage: Double(count) / Double(total) * 100)
        }.sorted { $0.count > $1.count }
    }

    private var filteredPlatforms: [(platform: String, count: Int, percentage: Double)] {
        var counts = [String: Int]()
        for r in filtered { counts[r.platform ?? "No link", default: 0] += 1 }
        let total = max(filtered.count, 1)
        return counts.map { ($0.key, $0.value, Double($0.value) / Double(total) * 100) }.sorted { $0.1 > $1.1 }
    }

    private var filteredRecurring: [(title: String, count: Int)] {
        var counts = [String: Int]()
        for r in filtered { counts[r.title, default: 0] += 1 }
        return counts.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }.prefix(5).map { $0 }
    }

    // MARK: - Helpers

    private func compactHourLabel(_ label: String) -> String {
        label.replacingOccurrences(of: " AM", with: "a").replacingOccurrences(of: " PM", with: "p").replacingOccurrences(of: "\u{2013}", with: "–")
    }

    private func extractDisplayName(_ raw: String) -> String {
        if raw.contains("@") {
            let local = String(raw.prefix(while: { $0 != "@" }))
            return local.replacingOccurrences(of: ".", with: " ").split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined(separator: " ")
        }
        return raw
    }

    private func formatMinutes(_ mins: Int) -> String {
        if mins >= 60 { let h = mins / 60, m = mins % 60; return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(mins)m"
    }

    private struct DayInfo { let initial: String; let count: Int; let isToday: Bool }

    private var focusSessionsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return focus.sessions.filter { $0.date > weekAgo }.count
    }

    private var weekDayData: [DayInfo] {
        let cal = Calendar.current; let today = Date()
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: today) else { return [] }
        let initials = ["M", "T", "W", "T", "F", "S", "S"]
        let todayWeekday = cal.component(.weekday, from: today)
        let todayIndex = todayWeekday == 1 ? 6 : todayWeekday - 2
        let weekRecords = stats.records.filter { $0.date >= weekInterval.start }
        var counts = [Int](repeating: 0, count: 7)
        for record in weekRecords {
            let wd = cal.component(.weekday, from: record.date)
            counts[wd == 1 ? 6 : wd - 2] += 1
        }
        return (0..<7).map { DayInfo(initial: initials[$0], count: counts[$0], isToday: $0 == todayIndex) }
    }
}

// MARK: - Heatmap (fully isolated — hover state stays local)

private struct HeatmapView: View {
    @ObservedObject var stats: StatsService
    let accentColor: Color

    @State private var hoverText: String = ""
    private let card = Color.white.opacity(0.04)
    private let cardBorder = Color.white.opacity(0.06)

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let data = stats.heatmapData()
        let maxCount = max(data.values.max() ?? 1, 1)
        let startDate = cal.date(byAdding: .day, value: -364, to: today)!
        let startWeekday = cal.component(.weekday, from: startDate)
        let mondayOffset = startWeekday == 1 ? -6 : 2 - startWeekday
        let alignedStart = cal.date(byAdding: .day, value: mondayOffset, to: startDate)!
        let totalAlignedDays = cal.dateComponents([.day], from: alignedStart, to: today).day! + 1
        let weeks = (totalAlignedDays + 6) / 7

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "square.grid.3x3.fill").font(.system(size: 9)).foregroundStyle(P.text3)
                Text("ACTIVITY")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(P.text3).tracking(1)
                Spacer()
                Text("\(stats.totalMeetings) total")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(P.text3)
            }

            VStack(alignment: .leading, spacing: 4) {
                let labelW: CGFloat = 16
                let gap: CGFloat = 3
                GeometryReader { geo in
                    let availW = geo.size.width - labelW - gap
                    let cs = max(floor((availW - CGFloat(weeks - 1) * gap) / CGFloat(weeks)), 6)
                    let colW = cs + gap

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 0) {
                            Spacer().frame(width: labelW + gap)
                            ForEach(0..<weeks, id: \.self) { weekIdx in
                                let weekStart = cal.date(byAdding: .day, value: weekIdx * 7, to: alignedStart)!
                                let monthDay = cal.component(.day, from: weekStart)
                                if monthDay <= 7 {
                                    Text(shortMonth(weekStart))
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(P.text3).fixedSize()
                                        .frame(width: colW, alignment: .leading)
                                } else {
                                    Spacer().frame(width: colW)
                                }
                            }
                        }

                        HStack(spacing: gap) {
                            VStack(spacing: gap) {
                                ForEach(0..<7, id: \.self) { dayIdx in
                                    Text(dayIdx % 2 == 0 ? ["M", "", "W", "", "F", "", "S"][dayIdx] : "")
                                        .font(.system(size: 7, weight: .medium))
                                        .foregroundStyle(P.text3)
                                        .frame(width: labelW, height: cs)
                                }
                            }
                            ForEach(0..<weeks, id: \.self) { weekIdx in
                                VStack(spacing: gap) {
                                    ForEach(0..<7, id: \.self) { dayIdx in
                                        let dayOffset = weekIdx * 7 + dayIdx
                                        let date = cal.date(byAdding: .day, value: dayOffset, to: alignedStart)!
                                        let count = data[cal.startOfDay(for: date)] ?? 0
                                        let isFuture = date > today
                                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                                            .fill(isFuture ? .clear : colorFor(count: count, max: maxCount))
                                            .frame(width: cs, height: cs)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                                    .strokeBorder(isFuture ? .white.opacity(0.02) : .clear, lineWidth: 0.5)
                                            )
                                            .contentShape(Rectangle())
                                            .onHover { hovering in
                                                hoverText = hovering && !isFuture ? tooltip(date: date, count: count) : ""
                                            }
                                    }
                                }
                            }
                        }
                    }
                }
                .aspectRatio(CGFloat(weeks + 1) / 8.5, contentMode: .fit)

                HStack(spacing: 4) {
                    Text(hoverText.isEmpty ? " " : hoverText)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(hoverText.isEmpty ? .clear : P.text2)
                    Spacer()
                    Text("Less").font(.system(size: 8)).foregroundStyle(P.text3)
                    ForEach([0, 1, 2, 3, 4], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(colorFor(count: level, max: 4))
                            .frame(width: 10, height: 10)
                    }
                    Text("More").font(.system(size: 8)).foregroundStyle(P.text3)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(cardBorder, lineWidth: 0.5))
    }

    private func colorFor(count: Int, max: Int) -> Color {
        guard count > 0 else { return .white.opacity(0.03) }
        let ratio = min(Double(count) / Double(max), 1.0)
        if ratio <= 0.25 { return accentColor.opacity(0.2) }
        if ratio <= 0.5 { return accentColor.opacity(0.4) }
        if ratio <= 0.75 { return accentColor.opacity(0.65) }
        return accentColor
    }

    private func tooltip(date: Date, count: Int) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        return "\(count == 0 ? "No meetings" : count == 1 ? "1 meeting" : "\(count) meetings") on \(f.string(from: date))"
    }

    private func shortMonth(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f.string(from: date)
    }
}
