import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {

    @ObservedObject var appState: AppState
    @ObservedObject var settings: UserSettings
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    countdownSection
                    displaySection
                    statsSection
                    generalSection
                }
                .padding(16)
            }

            Divider()

            Text("OnAir v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
        }
        .frame(width: 340)
    }

    private var countdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("COUNTDOWN")

            HStack {
                Text("Lead time")
                    .font(.system(size: 12))
                Spacer()
                Picker("", selection: $settings.leadTimeSeconds) {
                    ForEach(UserSettings.LeadTimePreset.allCases, id: \.rawValue) { preset in
                        Text(preset.displayName).tag(preset.seconds)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)
            }

            HStack {
                Text("Volume")
                    .font(.system(size: 12))
                Spacer()
                Slider(value: $settings.volume, in: 0...1)
                    .frame(width: 140)
                    .onChange(of: settings.volume) { newValue in
                        appState.countdownPlayer.updateVolume(Float(newValue))
                    }
            }

            HStack {
                Text("Sound")
                    .font(.system(size: 12))
                Spacer()
                Text(soundLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Button("Change") {
                    selectSoundFile()
                }
                .controlSize(.small)
            }

            HStack {
                Spacer()
                Button {
                    appState.countdownPlayer.playTestSound(
                        customPath: settings.customSoundPath,
                        volume: Float(settings.volume)
                    )
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                        Text("Test Sound")
                    }
                }
                .controlSize(.small)
            }
        }
    }

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("DISPLAY")

            Toggle("Show past meetings", isOn: $settings.showPastMeetings)
                .font(.system(size: 12))
                .toggleStyle(.switch)
                .controlSize(.small)

            if !appState.calendarService.availableCalendars.isEmpty {
                Text("Calendars:")
                    .font(.system(size: 12))

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
                    .padding(.leading, 8)
                }
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("STATS")

            Toggle("Track meeting stats", isOn: $settings.trackStats)
                .font(.system(size: 12))
                .toggleStyle(.switch)
                .controlSize(.small)

            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Text("Clear All Stats")
                    .font(.system(size: 12))
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

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("GENERAL")

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
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .tracking(1)
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

        // Close popover so it doesn't interfere with the panel
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
