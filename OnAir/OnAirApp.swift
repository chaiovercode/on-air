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
    private var onboardingWindow: NSWindow?
    let appState = AppState()

    private var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarManager = StatusBarManager(appState: appState)

        if hasCompletedOnboarding {
            Task { await appState.start() }
        } else {
            showOnboarding()
        }
    }

    private func showOnboarding() {
        let view = OnboardingView { [weak self] in
            guard let self else { return }
            self.hasCompletedOnboarding = true
            self.onboardingWindow?.close()
            self.onboardingWindow = nil
            Task { await self.appState.start() }
        }

        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = ""
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(red: 0.09, green: 0.08, blue: 0.07, alpha: 1)
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false
        window.hasShadow = true
        onboardingWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.stop()
    }
}
