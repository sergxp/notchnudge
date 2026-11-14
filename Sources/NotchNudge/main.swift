import AppKit
import Carbon.HIToolbox
import ServiceManagement

/// System-wide shortcut using the Carbon API (needs no special permission).
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    fileprivate let action: () -> Void

    init(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return noErr }
            Unmanaged<HotKey>.fromOpaque(data).takeUnretainedValue().action()
            return noErr
        }, 1, &spec, me, &handler)
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), EventHotKeyID(signature: OSType(0x4E4E4447), id: 1),
                            GetApplicationEventTarget(), 0, &ref)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store = ReminderStore()
    var controller: NotchController!
    var statusItem: NSStatusItem!
    var hotKey: HotKey?
    private var pauseItem: NSMenuItem!
    private var loginItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = NotchController(store: store)
        hotKey = HotKey(keyCode: kVK_ANSI_N, modifiers: controlKey | optionKey) { [weak self] in
            self?.controller.toggleOpen()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "bell.badge", accessibilityDescription: "NotchNudge")

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(item("Open Drawer   \u{2303}\u{2325}N", #selector(openDrawer)))
        menu.addItem(item("Show Next Reminder Now", #selector(showNext)))
        menu.addItem(.separator())
        pauseItem = item("Pause All Nudges", #selector(togglePause))
        loginItem = item("Launch at Login", #selector(toggleLogin))
        menu.addItem(pauseItem)
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(item("Quit NotchNudge", #selector(quit), key: "q"))
        statusItem.menu = menu

    }

    func menuWillOpen(_ menu: NSMenu) {
        pauseItem.state = store.allPaused ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    private func item(_ title: String, _ sel: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc func openDrawer() { controller.open(focus: true) }
    @objc func showNext() { controller.showNow() }
    @objc func togglePause() { store.allPaused.toggle() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            NSLog("NotchNudge: launch-at-login change failed: \(error)")
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
