import SwiftUI

@main
struct OnAirApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarManager: StatusBarManager?
    private let appState = AppState()

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
