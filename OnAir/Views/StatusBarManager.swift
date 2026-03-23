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
        popover?.contentSize = NSSize(width: 320, height: 400)
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
        attributed.append(NSAttributedString(string: textWithoutDot, attributes: [
            .font: NSFont.menuBarFont(ofSize: 0)
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
