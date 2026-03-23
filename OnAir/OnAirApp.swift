import SwiftUI

@main
struct OnAirApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(appState: appDelegate.appState, settings: appDelegate.appState.settings)
                .frame(width: 420, height: 500)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarManager: StatusBarManager?
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarManager = StatusBarManager(appState: appState)

        Task {
            await appState.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.stop()
    }
}
