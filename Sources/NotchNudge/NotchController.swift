import AppKit
import SwiftUI

enum DrawerMode: Equatable {
    case closed
    case open
    case peek(UUID)
}

final class NotchPanel: NSPanel {
    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        isFloatingPanel = true
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    // macOS normally shoves windows below the menu bar. We need to sit up in the notch.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Lets buttons work on the first click, even when the panel is not focused.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Owns the floating panel, watches the mouse, and fires reminders on schedule.
final class NotchController: ObservableObject {
    @Published private(set) var mode: DrawerMode = .closed
    @Published var peekProgress: Double = 0
    @Published private(set) var notchSize: CGSize = CGSize(width: 190, height: 32)
    @Published var focusToken = 0
    /// Set while a reminder is being edited: Esc cancels the edit instead of closing the drawer.
    var onEscape: (() -> Void)?

    let store: ReminderStore
    private var panel: NotchPanel!
    private var screen: NSScreen
    private var timer: Timer?
    private var tick = 0
    private var hoverStart: Date?
    private var outsideSince: Date?
    private var sticky = false            // true once the user clicks in: stays open until Esc / click away
    private var peekElapsed: TimeInterval = 0
    let peekDuration: TimeInterval = 12

    static let panelSize = CGSize(width: 620, height: 540)
    static let openSize = CGSize(width: 480, height: 440)
    var peekSize: CGSize { CGSize(width: 440, height: notchSize.height + 96) }
    var earRadius: CGFloat { mode == .closed ? 6 : 12 }

    var drawerSize: CGSize {
        switch mode {
        case .closed: return notchSize
        case .open: return Self.openSize
        case .peek: return peekSize
        }
    }

    /// Preview-only: no window, no timers. Used to draw screenshots.
    init(previewStore: ReminderStore, mode: DrawerMode, notchSize: CGSize, peekProgress: Double = 0) {
        store = previewStore
        screen = NSScreen.screens.first ?? NSScreen()
        self.mode = mode
        self.notchSize = notchSize
        self.peekProgress = peekProgress
    }

    init(store: ReminderStore) {
        self.store = store
        screen = Self.pickScreen()
        notchSize = Self.notch(for: screen)

        panel = NotchPanel(frame: panelFrame())
        let root = RootView().environmentObject(self).environmentObject(store)
        let host = FirstClickHostingView(rootView: AnyView(root))
        host.sizingOptions = []
        panel.contentView = host
        panel.ignoresMouseEvents = true
        panel.setFrame(panelFrame(), display: true)
        panel.orderFrontRegardless()

        timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.step() }
        RunLoop.main.add(timer!, forMode: .common)

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reposition()
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: panel, queue: .main) { [weak self] _ in
            if self?.mode == .open { self?.sticky = true }
        }
        // Clicks in other apps close the drawer.
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.mode == .open { self?.close() }
        }
        // Esc closes.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            if e.keyCode == 53, let self, self.mode != .closed {
                if let cancelEdit = self.onEscape { self.onEscape = nil; cancelEdit() } else { self.close() }
                return nil
            }
            return e
        }
    }

    // MARK: Public actions

    func toggleOpen() { mode == .open ? close() : open(focus: true) }

    /// focus: grab the keyboard so you can type right away.
    /// sticky: stay open until Esc or a click elsewhere (instead of closing when the mouse leaves).
    func open(focus: Bool, sticky stay: Bool? = nil) {
        setMode(.open)
        sticky = stay ?? focus
        if focus {
            panel.makeKey()
            focusToken += 1
        }
    }

    func close() { setMode(.closed) }

    func showNow(_ id: UUID? = nil) {
        guard let r = id.flatMap(store.reminder) ?? store.upNext ?? store.reminders.first else { return }
        store.markShown(r.id)
        peek(r.id)
    }

    func dismissPeek(snooze: TimeInterval? = nil) {
        if case .peek(let id) = mode, let snooze { store.snooze(id, for: snooze) }
        close()
    }

    // MARK: Loop

    private func step() {
        let m = NSEvent.mouseLocation
        switch mode {
        case .closed:
            if hotZone.contains(m) {
                if hoverStart == nil { hoverStart = Date() }
                else if Date().timeIntervalSince(hoverStart!) > 0.12 { hoverStart = nil; open(focus: false) }
            } else { hoverStart = nil }

        case .open:
            guard !sticky else { break }
            if drawerScreenRect.insetBy(dx: -16, dy: -16).contains(m) { outsideSince = nil }
            else {
                if outsideSince == nil { outsideSince = Date() }
                else if Date().timeIntervalSince(outsideSince!) > 0.4 { close() }
            }

        case .peek(let id):
            if store.reminder(id) == nil { close(); break }
            if !drawerScreenRect.contains(m) { peekElapsed += 0.05 }   // hovering holds it open
            peekProgress = min(1, peekElapsed / peekDuration)
            if peekElapsed >= peekDuration { close() }
        }

        tick += 1
        if tick % 20 == 0 {
            store.now = Date()
            if mode == .closed, let due = store.due() {
                store.markShown(due.id)
                peek(due.id)
            }
        }
    }

    private func peek(_ id: UUID) {
        peekElapsed = 0
        peekProgress = 0
        setMode(.peek(id))
        NSSound(named: "Glass")?.play()
    }

    private func setMode(_ new: DrawerMode) {
        guard new != mode else { return }
        let wasKey = panel.isKeyWindow
        outsideSince = nil
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { mode = new }
        panel.ignoresMouseEvents = (new == .closed)
        if new == .closed {
            sticky = false
            onEscape = nil
            // Hand keyboard focus back to whatever app was in front.
            if wasKey {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                    guard let self, self.mode == .closed else { return }
                    self.panel.orderOut(nil)
                    self.panel.orderFrontRegardless()
                }
            }
        }
    }

    // MARK: Geometry

    private var hotZone: NSRect {
        let f = screen.frame
        return NSRect(x: f.midX - notchSize.width / 2 - 8, y: f.maxY - notchSize.height,
                      width: notchSize.width + 16, height: notchSize.height + 2)
    }

    private var drawerScreenRect: NSRect {
        let s = drawerSize, f = screen.frame
        let w = s.width + earRadius * 2
        return NSRect(x: f.midX - w / 2, y: f.maxY - s.height, width: w, height: s.height)
    }

    private func panelFrame() -> NSRect {
        let f = screen.frame, s = Self.panelSize
        return NSRect(x: f.midX - s.width / 2, y: f.maxY - s.height, width: s.width, height: s.height)
    }

    private func reposition() {
        screen = Self.pickScreen()
        notchSize = Self.notch(for: screen)
        panel.setFrame(panelFrame(), display: true)
    }

    private static func pickScreen() -> NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private static func notch(for s: NSScreen) -> CGSize {
        let h = s.safeAreaInsets.top > 0 ? s.safeAreaInsets.top : max(24, s.frame.maxY - s.visibleFrame.maxY)
        var w: CGFloat = 190
        if let l = s.auxiliaryTopLeftArea, let r = s.auxiliaryTopRightArea {
            w = s.frame.width - l.width - r.width
        }
        return CGSize(width: w, height: h)
    }
}
