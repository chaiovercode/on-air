import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarManager: NSObject {

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    private var blinkTimer: Timer?
    private var blinkVisible = true

    init(appState: AppState) {
        self.appState = appState
        super.init()
        setupStatusItem()
        setupPopover()
        observeState()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateTitle()
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 340, height: 450)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: PopoverView(appState: appState)
        )
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

        // Start or stop blink timer
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

        // Add colored dot based on state
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

        // Strip the "● " prefix from menuBarText since we're using a real dot
        let textWithoutDot = text.hasPrefix("●") ? String(text.dropFirst(2)) : text

        // Blink effect: alternate between visible and hidden text
        let textAlpha: CGFloat = blinkHidden ? 0.0 : 1.0
        attributed.append(NSAttributedString(string: textWithoutDot, attributes: [
            .font: NSFont.menuBarFont(ofSize: 0),
            .foregroundColor: NSColor.labelColor.withAlphaComponent(textAlpha)
        ]))

        button.attributedTitle = attributed
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
            stopEventMonitor()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startEventMonitor()
        }
    }

    private func startEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover?.performClose(nil)
            self?.stopEventMonitor()
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
