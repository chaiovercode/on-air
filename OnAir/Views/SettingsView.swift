import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {

    @ObservedObject var appState: AppState
    @ObservedObject var settings: UserSettings
    @State private var showClearConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                countdownSection
                displaySection
                statsSection
                generalSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Countdown

    private var countdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Countdown", icon: "speaker.wave.2")

            settingRow("Lead time") {
                Picker("", selection: $settings.leadTimeSeconds) {
                    ForEach(UserSettings.LeadTimePreset.allCases, id: \.rawValue) { preset in
                        Text(preset.displayName).tag(preset.seconds)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
            }

            settingRow("Volume") {
                Slider(value: $settings.volume, in: 0...1)
                    .frame(width: 130)
                    .onChange(of: settings.volume) { newValue in
                        appState.countdownPlayer.updateVolume(Float(newValue))
                    }
            }

            settingRow("Sound") {
                HStack(spacing: 6) {
                    Text(soundLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Button("Change") {
                        selectSoundFile()
                    }
                    .controlSize(.mini)
                }
            }

            HStack {
                Spacer()
                Button {
                    appState.countdownPlayer.playTestSound(
                        customPath: settings.customSoundPath,
                        volume: Float(settings.volume)
                    )
                } label: {
                    Label("Test Sound", systemImage: "play.fill")
                        .font(.system(size: 11))
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Display", icon: "eye")

            Toggle("Show past meetings", isOn: $settings.showPastMeetings)
                .font(.system(size: 12))
                .toggleStyle(.switch)
                .controlSize(.small)

            if !appState.calendarService.availableCalendars.isEmpty {
                Text("Calendars")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(appState.calendarService.availableCalendars, id: \.id) { cal in
                        Toggle(cal.title, isOn: Binding(
                            get: { settings.isCalendarEnabled(cal.id) },
                            set: { _ in
                                settings.toggleCalendar(cal.id)
                                appState.refreshEvents()
                            }
                        ))
                        .font(.system(size: 11))
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(.leading, 4)
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Stats", icon: "chart.bar")

            Toggle("Track meeting stats", isOn: $settings.trackStats)
                .font(.system(size: 12))
                .toggleStyle(.switch)
                .controlSize(.small)

            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Label("Clear All Stats", systemImage: "trash")
                    .font(.system(size: 11))
            }
            .controlSize(.small)
            .alert("Clear all meeting stats?", isPresented: $showClearConfirmation) {
                Button("Clear", role: .destructive) {
                    appState.statsService.clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("General", icon: "gearshape")

            Toggle("Launch at login", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { newValue in
                    settings.launchAtLogin = newValue
                    updateLoginItem(enabled: newValue)
                }
            ))
            .font(.system(size: 12))
            .toggleStyle(.switch)
            .controlSize(.small)

            HStack {
                Spacer()
                Text("OnAir v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.red)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1)
        }
    }

    private func settingRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
            Spacer()
            content()
        }
    }

    private var soundLabel: String {
        if let path = settings.customSoundPath {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        return "Default"
    }

    private func selectSoundFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.treatsFilePackagesAsDirectories = false
        panel.resolvesAliases = true
        NSApp.keyWindow?.close()

        if panel.runModal() == .OK, let url = panel.url {
            copyToAppSupport(url)
        }
    }

    private func copyToAppSupport(_ sourceURL: URL) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let onairDir = appSupport.appendingPathComponent("OnAir")
        try? FileManager.default.createDirectory(at: onairDir, withIntermediateDirectories: true)
        let dest = onairDir.appendingPathComponent("countdown.\(sourceURL.pathExtension)")
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: dest)
            settings.customSoundPath = dest.path
            appState.soundWarning = false
        } catch {
            appState.soundWarning = true
        }
    }

    private func updateLoginItem(enabled: Bool) {
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}
