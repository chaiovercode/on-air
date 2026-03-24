import AppKit
import Combine
import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("OnAir.openSettings")
    static let toggleNewEvent = Notification.Name("OnAir.toggleNewEvent")
    static let toggleSearch = Notification.Name("OnAir.toggleSearch")
    static let dismissOverlays = Notification.Name("OnAir.dismissOverlays")
}

@MainActor
final class StatusBarManager: NSObject {

    private var statusItem: NSStatusItem?
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    private var blinkTimer: Timer?
    private var blinkVisible = true
    private var settingsWindow: NSWindow?

    init(appState: AppState) {
        self.appState = appState
        super.init()
        setupStatusItem()
        observeState()
        observeSettingsNotification()
        setupKeyboardShortcuts()
    }

    private func setupKeyboardShortcuts() {
        // Not used — shortcuts are handled via NSMenuItem keyEquivalents on the menu
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateTitle()
        }

        let menu = NSMenu()
        let menuItem = NSMenuItem()
        let hostingView = NSHostingView(rootView: PopoverView(appState: appState))
        let wrapper = KeyHandlingView(frame: NSRect(x: 0, y: 0, width: 300, height: 700))
        hostingView.frame = wrapper.bounds
        hostingView.autoresizingMask = [.width, .height]
        wrapper.addSubview(hostingView)
        menuItem.view = wrapper
        menu.addItem(menuItem)
        statusItem?.menu = menu
    }

    private func observeSettingsNotification() {
        NotificationCenter.default.addObserver(forName: .openSettings, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.statusItem?.menu?.cancelTracking()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self?.showSettings()
                }
            }
        }
    }

    private func showSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let bgColor = NSColor(red: 0.098, green: 0.098, blue: 0.106, alpha: 1)

        let view = SettingsView(appState: appState, settings: appState.settings)
        let controller = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: controller)
        window.title = "OnAir Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        window.backgroundColor = bgColor
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false
        window.hasShadow = true
        settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func observeState() {
        appState.$nextEvent
            .combineLatest(appState.$secondsUntilNext, appState.$countdownActive, appState.$calendarAccessDenied)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateTitle()
            }
            .store(in: &cancellables)
    }

    private func updateTitle() {
        guard let button = statusItem?.button else { return }

        let seconds = appState.secondsUntilNext
        let shouldBlink = seconds > 0 && seconds <= 10

        if shouldBlink && blinkTimer == nil {
            blinkVisible = true
            blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.blinkVisible.toggle()
                    self.renderTitle(button: button, blinkHidden: !self.blinkVisible)
                }
            }
        } else if !shouldBlink && blinkTimer != nil {
            blinkTimer?.invalidate()
            blinkTimer = nil
            blinkVisible = true
        }

        renderTitle(button: button, blinkHidden: shouldBlink && !blinkVisible)
    }

    private func renderTitle(button: NSStatusBarButton, blinkHidden: Bool) {
        let text = appState.menuBarText
        let attributed = NSMutableAttributedString()

        let dotColor: NSColor
        if appState.calendarAccessDenied {
            dotColor = .systemOrange
        } else if appState.isNextEventInProgress {
            dotColor = .systemGreen
        } else if appState.nextEvent != nil {
            dotColor = .systemRed
        } else {
            dotColor = .systemGray
        }

        let dotAttachment = NSTextAttachment()
        let dotImage = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
            dotColor.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        dotAttachment.image = dotImage
        attributed.append(NSAttributedString(attachment: dotAttachment))
        attributed.append(NSAttributedString(string: " "))

        let textWithoutDot = text.hasPrefix("●") ? String(text.dropFirst(2)) : text

        let textAlpha: CGFloat = blinkHidden ? 0.0 : 1.0
        attributed.append(NSAttributedString(string: textWithoutDot, attributes: [
            .font: NSFont.menuBarFont(ofSize: 0),
            .foregroundColor: NSColor.labelColor.withAlphaComponent(textAlpha)
        ]))

        button.attributedTitle = attributed
    }
}

// MARK: - View wrapper that intercepts key events inside the NSMenu

final class KeyHandlingView: NSView {
    override var acceptsFirstResponder: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // ⌘N — new event
        if flags == .command, event.charactersIgnoringModifiers == "n" {
            NotificationCenter.default.post(name: .toggleNewEvent, object: nil)
            return true
        }
        // ⌘F — search
        if flags == .command, event.charactersIgnoringModifiers == "f" {
            NotificationCenter.default.post(name: .toggleSearch, object: nil)
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        // Esc — dismiss overlays
        if event.keyCode == 53 {
            NotificationCenter.default.post(name: .dismissOverlays, object: nil)
            return
        }
        super.keyDown(with: event)
    }
}
