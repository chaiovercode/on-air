import AppKit
import Combine
import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("OnAir.openSettings")
    static let toggleNewEvent = Notification.Name("OnAir.toggleNewEvent")
    static let toggleSearch = Notification.Name("OnAir.toggleSearch")
    static let dismissOverlays = Notification.Name("OnAir.dismissOverlays")
    static let toggleTimeline = Notification.Name("OnAir.toggleTimeline")
    static let popoverWidthChange = Notification.Name("OnAir.popoverWidthChange")
}

@MainActor
final class StatusBarManager: NSObject {

    private var statusItem: NSStatusItem?
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    private var blinkTimer: Timer?
    private var blinkVisible = true
    private var settingsWindow: NSWindow?
    private var popoverPanel: NSPanel?
    private var overlayPanel: NSPanel?
    private var clickTarget: AnyObject?
    private var eventMonitor: Any?
    private var keyMonitor: Any?

    init(appState: AppState) {
        self.appState = appState
        super.init()
        setupStatusItem()
        observeState()
        observeSettingsNotification()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let target = PopoverClickTarget { [weak self] in
            self?.togglePopover()
        }
        clickTarget = target

        if let button = statusItem?.button {
            updateTitle()
            button.action = #selector(PopoverClickTarget.handleClick)
            button.target = target
        }
    }

    private func createPanel() -> NSPanel {
        let hostingView = NSHostingView(rootView: PopoverView(appState: appState))

        let panel = KeyablePanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 700),
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = true
        panel.hidesOnDeactivate = true

        // Round corners
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 14
        hostingView.layer?.masksToBounds = true

        panel.contentView = hostingView
        return panel
    }

    private func togglePopover() {
        if let panel = popoverPanel, panel.isVisible {
            hidePopover()
            return
        }

        // Stop countdown sound
        if appState.countdownPlayer.isPlaying {
            appState.countdownPlayer.stop()
            appState.countdownActive = false
        }

        guard let button = statusItem?.button,
              let buttonWindow = button.window else { return }

        let panel = popoverPanel ?? createPanel()
        popoverPanel = panel

        // Position below status bar button
        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        let panelW = panel.frame.width
        let x = screenRect.midX - panelW / 2
        let y = screenRect.minY - panel.frame.height - 6

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Close on outside click
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hidePopover()
        }

        // Keyboard shortcuts
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // ESC — dismiss overlay first, then popover
            if event.keyCode == 53 {
                if self.overlayPanel != nil {
                    self.dismissOverlay()
                } else {
                    self.hidePopover()
                }
                return nil
            }

            // Cmd+N — new event
            if flags == .command, event.charactersIgnoringModifiers == "n" {
                NotificationCenter.default.post(name: .toggleNewEvent, object: nil)
                return nil
            }

            // Cmd+F — search
            if flags == .command, event.charactersIgnoringModifiers == "f" {
                NotificationCenter.default.post(name: .toggleSearch, object: nil)
                return nil
            }

            // Cmd+, — settings
            if flags == .command, event.charactersIgnoringModifiers == "," {
                NotificationCenter.default.post(name: .dismissOverlays, object: nil)
                NotificationCenter.default.post(name: .openSettings, object: nil)
                return nil
            }

            // T — toggle today timeline
            if flags.isEmpty, event.charactersIgnoringModifiers == "t" {
                NotificationCenter.default.post(name: .toggleTimeline, object: nil)
                return nil
            }

            // J — join next meeting link
            if flags.isEmpty, event.charactersIgnoringModifiers == "j" {
                if let link = self.appState.nextEvent?.meetingLink {
                    NSWorkspace.shared.open(link.url)
                    return nil
                }
            }

            return event
        }
    }

    private func showOverlay(isSearch: Bool) {
        if overlayPanel != nil { dismissOverlay(); return }
        guard let mainPanel = popoverPanel, mainPanel.isVisible else { return }

        let presented = Binding<Bool>(
            get: { true },
            set: { [weak self] v in if !v { self?.dismissOverlay() } }
        )

        let content: AnyView
        if isSearch {
            content = AnyView(SearchView(appState: appState, isPresented: presented))
        } else {
            content = AnyView(NewEventView(appState: appState, isPresented: presented))
        }

        let hosting = NSHostingController(rootView:
            content
                .frame(width: 330)
                .background(Color(red: 0.071, green: 0.063, blue: 0.043))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.5), radius: 24, y: 8)
        )

        let panel = KeyablePanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: true)
        panel.contentViewController = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar + 1
        panel.hasShadow = false // SwiftUI handles shadow

        // Center over the main popover panel
        let mainFrame = mainPanel.frame
        let w: CGFloat = 350
        let h: CGFloat = isSearch ? 460 : 420
        let x = mainFrame.midX - w / 2 + 10
        let y = mainFrame.midY - h / 2 + 40
        panel.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        panel.orderFront(nil)

        overlayPanel = panel
    }

    private func dismissOverlay() {
        overlayPanel?.orderOut(nil)
        overlayPanel = nil
    }

    private func hidePopover() {
        dismissOverlay()
        popoverPanel?.orderOut(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func observeSettingsNotification() {
        // Overlay panels for new event / search
        NotificationCenter.default.addObserver(forName: .toggleNewEvent, object: nil, queue: nil) { [weak self] _ in
            DispatchQueue.main.async { self?.showOverlay(isSearch: false) }
        }
        NotificationCenter.default.addObserver(forName: .toggleSearch, object: nil, queue: nil) { [weak self] _ in
            DispatchQueue.main.async { self?.showOverlay(isSearch: true) }
        }
        NotificationCenter.default.addObserver(forName: .dismissOverlays, object: nil, queue: nil) { [weak self] _ in
            DispatchQueue.main.async { self?.dismissOverlay() }
        }

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
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let bgColor = NSColor(red: 0.071, green: 0.063, blue: 0.043, alpha: 1)

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
            .combineLatest(appState.$secondsUntilNext, appState.$countdownActive, appState.$wrapUpAlert)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateTitle()
            }
            .store(in: &cancellables)

        // Update menu bar when focus timer changes — only on minute boundaries (or every sec in last 60s)
        appState.focusService.$secondsRemaining
            .receive(on: RunLoop.main)
            .filter { $0 <= 60 || $0 % 60 == 0 }
            .sink { [weak self] _ in
                self?.updateTitle()
            }
            .store(in: &cancellables)

        // Also update when focus starts/stops
        appState.focusService.$isRunning
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

// MARK: - Keyable panel (borderless panels refuse key status by default)

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - Click trampoline (non-@MainActor so #selector works)

final class PopoverClickTarget: NSObject {
    private let handler: @MainActor () -> Void

    init(handler: @MainActor @escaping () -> Void) {
        self.handler = handler
        super.init()
    }

    @objc func handleClick() {
        MainActor.assumeIsolated { handler() }
    }
}
