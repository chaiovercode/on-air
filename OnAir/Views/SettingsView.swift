import Collaboration
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Palette

private enum P {
    static let bg = Color(red: 0.098, green: 0.098, blue: 0.106)
    static let accent = Color(red: 0.9, green: 0.25, blue: 0.2)
    static let divider = Color.white.opacity(0.07)
    static let sectionTitle = Color.white.opacity(0.45)
    static let rowBg = Color.white.opacity(0.035)
    static let rowBorder = Color.white.opacity(0.05)
    static let text1 = Color.white.opacity(0.85)
    static let text2 = Color.white.opacity(0.45)
    static let text3 = Color.white.opacity(0.25)
}

// MARK: - Settings

struct SettingsView: View {

    @ObservedObject var appState: AppState
    @ObservedObject var settings: UserSettings

    enum Tab: String, CaseIterable {
        case general = "General"
        case display = "Display"
        case stats = "Stats"
        case about = "About"

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .display: return "paintbrush.pointed"
            case .stats: return "chart.bar"
            case .about: return "info.circle"
            }
        }
    }

    @State private var selectedTab: Tab = .general
    @State private var showClearConfirm = false

    private var hasPreview: Bool {
        selectedTab == .general || selectedTab == .display
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 28)

            // Tab bar
            HStack(spacing: 6) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button { selectedTab = tab } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 10.5, weight: .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(selectedTab == tab ? P.accent : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selectedTab == tab ? P.accent.opacity(0.1) : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(selectedTab == tab ? P.accent.opacity(0.25) : .clear, lineWidth: 0.5)
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
                    case .stats: statsTab
                    case .about: aboutTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Right: live preview
                if hasPreview {
                    P.divider.frame(width: 0.5)
                    previewPanel.frame(width: 330)
                }
            }

            // Footer
            P.divider.frame(height: 0.5)
            HStack {
                Text("OnAir v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(P.text3)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .frame(width: 920, height: 640)
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
                    // Menu bar preview
                    Text("Menu Bar Preview")
                        .font(.system(size: 10))
                        .foregroundStyle(P.text3)
                        .padding(.top, 16)

                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(P.accent)
                        Text(Date().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(P.text1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )

                    // Live popover — scale to fit the 340px column
                    PopoverView(appState: appState)
                        .frame(width: 330, height: 700)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
                        .scaleEffect(0.78)
                        .frame(width: 330 * 0.72, height: 700 * 0.72)
                        .allowsHitTesting(false)
                        .padding(.bottom, 8)

                    Text("Changes apply instantly")
                        .font(.system(size: 10))
                        .foregroundStyle(P.text3)
                        .padding(.bottom, 12)
                }
            }
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Section("Startup") {
                    Row("Launch at login") {
                        Toggle("", isOn: Binding(
                            get: { settings.launchAtLogin },
                            set: { v in settings.launchAtLogin = v; updateLoginItem(enabled: v) }
                        )).toggleStyle(.switch).controlSize(.small).tint(P.accent)
                    }
                }

                Section("Countdown") {
                    Row("Lead time") {
                        Picker("", selection: $settings.leadTimeSeconds) {
                            ForEach(UserSettings.LeadTimePreset.allCases, id: \.rawValue) { p in
                                Text(p.displayName).tag(p.seconds)
                            }
                        }.pickerStyle(.menu).frame(width: 140)
                    }
                    Row("Volume") {
                        HStack(spacing: 6) {
                            Image(systemName: "speaker.fill").font(.system(size: 8)).foregroundStyle(P.text3)
                            Slider(value: $settings.volume, in: 0...1).frame(width: 110).tint(P.accent)
                                .onChange(of: settings.volume) { v in appState.countdownPlayer.updateVolume(Float(v)) }
                            Image(systemName: "speaker.wave.3.fill").font(.system(size: 8)).foregroundStyle(P.text3)
                        }
                    }
                    Row("Sound") {
                        Text(soundLabel).font(.system(size: 12)).foregroundStyle(P.text3).lineLimit(1)
                        Pill("Change…") { selectSoundFile() }
                        Pill("Test") {
                            appState.countdownPlayer.playTestSound(customPath: settings.customSoundPath, volume: Float(settings.volume))
                        }
                    }
                }

                Section("Data") {
                    Row("Track meeting stats") {
                        Toggle("", isOn: $settings.trackStats).toggleStyle(.switch).controlSize(.small).tint(P.accent)
                    }
                    Row("Clear all stats") {
                        Pill("Clear…") { showClearConfirm = true }
                    }
                    .alert("Clear all meeting stats?", isPresented: $showClearConfirm) {
                        Button("Clear", role: .destructive) { appState.statsService.clearAll() }
                        Button("Cancel", role: .cancel) {}
                    } message: { Text("This cannot be undone.") }
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 8)
        }
    }

    // MARK: - Display Tab

    private var displayTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Section("Agenda") {
                    Row("Show past meetings") {
                        Toggle("", isOn: $settings.showPastMeetings).toggleStyle(.switch).controlSize(.small).tint(P.accent)
                    }
                    Row("Hide empty days") {
                        Toggle("", isOn: $settings.hideEmptyDays).toggleStyle(.switch).controlSize(.small).tint(P.accent)
                    }
                }

                if !appState.calendarService.availableCalendars.isEmpty {
                    Section("Show Calendars") {
                        ForEach(appState.calendarService.availableCalendars, id: \.id) { cal in
                            Row(cal.title) {
                                Toggle("", isOn: Binding(
                                    get: { settings.isCalendarEnabled(cal.id) },
                                    set: { _ in settings.toggleCalendar(cal.id); appState.refreshEvents() }
                                )).toggleStyle(.switch).controlSize(.small).tint(P.accent)
                            }
                        }
                    }
                }

                Section("World Clock") {
                    ForEach(settings.worldClockIds, id: \.self) { tzId in
                        if let tz = TimeZone(identifier: tzId) {
                            Row(cityName(tzId)) {
                                Text(fmtTime(tz)).font(.system(size: 12, design: .monospaced)).foregroundStyle(P.text3)
                                Button {
                                    settings.worldClockIds.removeAll { $0 == tzId }
                                } label: {
                                    Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundStyle(P.text3)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    if settings.worldClockIds.count < 4 {
                        WorldClockAddRow(settings: settings)
                    }
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 8)
        }
    }

    // MARK: - Stats Tab (settings-native)

    private var statsTab: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if appState.statsService.records.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Spacer().frame(height: 60)
                        ZStack {
                            Circle().fill(P.accent.opacity(0.08)).frame(width: 80, height: 80).blur(radius: 20)
                            Circle().strokeBorder(Color.white.opacity(0.06), lineWidth: 1).frame(width: 56, height: 56)
                            Image(systemName: "chart.bar.xaxis.ascending")
                                .font(.system(size: 22, weight: .light)).foregroundStyle(P.text3)
                        }
                        Text("No stats yet").font(.system(size: 15, weight: .semibold)).foregroundStyle(P.text1)
                        Text("Attend a meeting and your\nstats will appear here.")
                            .font(.system(size: 12)).foregroundStyle(P.text2)
                            .multilineTextAlignment(.center).lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Section("Overview") {
                        StatRow("Meetings this week", value: "\(appState.statsService.meetingsThisWeek)", color: P.accent)
                        StatRow("Meetings this month", value: "\(appState.statsService.meetingsThisMonth)", color: Color(red: 0.35, green: 0.55, blue: 1.0))
                        StatRow("Total meetings", value: "\(appState.statsService.totalMeetings)", color: P.text2)
                        StatRow("Total time in meetings", value: appState.statsService.totalHoursDisplay, color: Color(red: 1.0, green: 0.6, blue: 0.2))
                    }

                    if !appState.statsService.busiestDays.isEmpty {
                        Section("Busiest Days") {
                            ForEach(appState.statsService.busiestDays.prefix(5), id: \.dayOfWeek) { day in
                                Row(String(day.dayOfWeek.prefix(3))) {
                                    BarIndicator(value: day.percentage, color: P.accent)
                                    Text("\(Int(day.percentage))%")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(P.text3).monospacedDigit()
                                        .frame(width: 32, alignment: .trailing)
                                }
                            }
                        }
                    }

                    if !appState.statsService.platformBreakdown.isEmpty {
                        Section("Platforms") {
                            ForEach(appState.statsService.platformBreakdown, id: \.platform) { item in
                                Row(item.platform) {
                                    BarIndicator(value: item.percentage, color: Color(red: 0.35, green: 0.55, blue: 1.0))
                                    Text("\(Int(item.percentage))%")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(P.text3).monospacedDigit()
                                        .frame(width: 32, alignment: .trailing)
                                }
                            }
                        }
                    }

                    if !appState.statsService.topMeetings.isEmpty {
                        Section("Recurring") {
                            ForEach(Array(appState.statsService.topMeetings.enumerated()), id: \.element.title) { i, item in
                                Row(item.title) {
                                    Text("\(item.count)×")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(i == 0 ? P.accent : P.text3)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 8)
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(P.accent.opacity(0.12)).frame(width: 120, height: 120).blur(radius: 30)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.96, green: 0.30, blue: 0.24), Color(red: 0.72, green: 0.12, blue: 0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 92, height: 92)
                    .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .center))
                        .frame(width: 92, height: 92))
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 36, weight: .medium)).foregroundStyle(.white.opacity(0.95))
            }
            .padding(.bottom, 28)
            Text("OnAir").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(P.text1).padding(.bottom, 4)
            Text("A meeting countdown for your menu bar").font(.system(size: 13)).foregroundStyle(P.text2).padding(.bottom, 8)
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(P.text3)

            Spacer()

            P.divider.frame(height: 0.5)
            HStack(spacing: 8) {
                if let img = CBIdentity(name: NSUserName(), authority: .local())?.image {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: 16, height: 16).clipShape(Circle())
                }
                Text("Registered to \(NSFullUserName())").font(.system(size: 10)).foregroundStyle(P.text3)
            }
            .padding(.vertical, 10)
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
