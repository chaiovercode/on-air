import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarManager: NSObject {

    private var statusItem: NSStatusItem?
    private var panel: FloatingPanel?
    private let appState: AppState
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    private var blinkTimer: Timer?
    private var blinkVisible = true

    init(appState: AppState) {
        self.appState = appState
        super.init()
        setupStatusItem()
        setupPanel()
        observeState()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateTitle()
            button.action = #selector(togglePanel)
            button.target = self
        }
    }

    private func setupPanel() {
        let hostingView = NSHostingView(rootView: PopoverView(appState: appState))
        panel = FloatingPanel(contentView: hostingView)
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

    @objc nonisolated private func togglePanel() {
        Task { @MainActor in
            self.doTogglePanel()
        }
    }

    private func doTogglePanel() {
        // Stop countdown sound on any click
        if appState.countdownPlayer.isPlaying {
            appState.countdownPlayer.stop()
            appState.countdownActive = false
        }

        guard let panel, let button = statusItem?.button else { return }

        if panel.isVisible {
            hidePanel()
        } else {
            // Position below the status bar button
            guard let buttonWindow = button.window else { return }
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = buttonWindow.convertToScreen(buttonRect)

            let panelWidth = panel.frame.width
            let x = screenRect.midX - panelWidth / 2
            let y = screenRect.minY - 6

            panel.setFrameTopLeftPoint(NSPoint(x: x, y: y))
            panel.makeKeyAndOrderFront(nil)
            startEventMonitor()
        }
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        stopEventMonitor()
    }

    private func startEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hidePanel()
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

// MARK: - Floating Panel (Custom Window)

final class FloatingPanel: NSPanel {

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 600),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        isOpaque = false
        backgroundColor = .clear
        level = .statusBar
        hasShadow = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = true
        animationBehavior = .utilityWindow

        // Glass background with vibrancy
        let rect = self.contentRect(forFrameRect: frame)
        let visualEffect = NSVisualEffectView()
        visualEffect.material = NSVisualEffectView.Material.popover
        visualEffect.state = NSVisualEffectView.State.active
        visualEffect.blendingMode = NSVisualEffectView.BlendingMode.behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        visualEffect.frame = rect

        self.contentView = visualEffect

        // Add SwiftUI content
        contentView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])
    }

    // Allow the panel to become key so controls work
    override var canBecomeKey: Bool { true }

    // Close on Escape
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            orderOut(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}
