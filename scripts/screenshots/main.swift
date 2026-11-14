// Renders the app's real SwiftUI views with sample data into PNGs for the README,
// plus the 1024px app icon. Run via scripts/screenshots.sh. Never reads your real reminders.
import AppKit
import SwiftUI

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/images")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let notch = CGSize(width: 185, height: 32)

// MARK: Sample data (stored in a throwaway temp file)

func demoStore() -> ReminderStore {
    let store = ReminderStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("notchnudge-demo-\(UUID().uuidString).json"))
    let t = Date()
    func r(_ text: String, _ every: TimeInterval, left: TimeInterval, paused: Bool = false) -> Reminder {
        Reminder(text: text, interval: every, nextFire: t.addingTimeInterval(left), isPaused: paused)
    }
    store.reminders = [
        r("Ship the onboarding pass before Friday's review", 3600, left: 760),
        r("Drink some water", 1800, left: 240),
        r("Stand up and stretch for a minute", 2700, left: 1900),
        r("Look away from the screen for 20 seconds", 1200, left: 1200, paused: true),
    ]
    store.now = t
    return store
}

// MARK: Fake desktop around the drawer

struct Desktop<Content: View>: View {
    var size = CGSize(width: 1280, height: 620)
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0.78, green: 0.84, blue: 0.93),
                                    Color(red: 0.93, green: 0.88, blue: 0.81),
                                    Color(red: 0.90, green: 0.79, blue: 0.70)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color(red: 1, green: 0.6, blue: 0.35).opacity(0.45), .clear], center: UnitPoint(x: 0.85, y: 0.9), startRadius: 0, endRadius: 520)
            RadialGradient(colors: [Color(red: 0.45, green: 0.6, blue: 1).opacity(0.35), .clear], center: UnitPoint(x: 0.12, y: 0.55), startRadius: 0, endRadius: 480)
            menuBar
            content.frame(width: size.width, height: size.height, alignment: .top)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var menuBar: some View {
        HStack(spacing: 18) {
            Image(systemName: "apple.logo").font(.system(size: 14, weight: .semibold))
            Text("Finder").font(.system(size: 13, weight: .bold))
            ForEach(["File", "Edit", "View", "Go", "Window", "Help"], id: \.self) { Text($0).font(.system(size: 13)) }
            Spacer()
            Image(systemName: "bell.badge").font(.system(size: 13, weight: .medium))
            Image(systemName: "wifi").font(.system(size: 13, weight: .medium))
            Image(systemName: "battery.75percent").font(.system(size: 15))
            Text("Fri 9:41 AM").font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(Color.black.opacity(0.8))
        .padding(.horizontal, 20)
        .frame(height: notch.height)
        .background(Color.white.opacity(0.35))
    }
}

func drawer(_ mode: DrawerMode, store: ReminderStore, progress: Double = 0) -> some View {
    let c = NotchController(previewStore: store, mode: mode, notchSize: notch, peekProgress: progress)
    return RootView()
        .environmentObject(c)
        .environmentObject(store)
        .frame(width: NotchController.panelSize.width, height: NotchController.panelSize.height)
}

// MARK: App icon

struct AppIcon: View {
    var body: some View {
        ZStack(alignment: .top) {
            Theme.accent
            // the black drawer hanging from the top edge
            ZStack {
                Image(systemName: "bell.fill")
                    .font(.system(size: 230, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .shadow(color: Theme.amber.opacity(0.7), radius: 30)
            }
            .frame(width: 560, height: 470)
            .padding(.horizontal, 34)
            .background(NotchShape(ear: 34, bottom: 120).fill(Color.black))
            .shadow(color: .black.opacity(0.35), radius: 30, y: 18)
        }
        .frame(width: 824, height: 824)
        .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 185, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 3))
        .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
        .frame(width: 1024, height: 1024)
    }
}

// MARK: Rendering (offscreen window at 2x so text stays crisp)

func render<V: View>(_ view: V, size: CGSize, name: String) {
    let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height).environment(\.colorScheme, .light))
    let win = NSWindow(contentRect: CGRect(x: 0, y: 0, width: size.width, height: size.height),
                       styleMask: .borderless, backing: .buffered, defer: false, screen: NSScreen.main)
    win.alphaValue = 0
    win.isOpaque = false
    win.backgroundColor = .clear
    win.contentView = host
    win.orderFront(nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.8))
    host.layoutSubtreeIfNeeded()
    let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
    host.cacheDisplay(in: host.bounds, to: rep)
    let url = outDir.appendingPathComponent(name)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    win.orderOut(nil)
    print("wrote \(url.path) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
}

NSApplication.shared.setActivationPolicy(.accessory)
let store = demoStore()

render(Desktop { drawer(.open, store: store) }, size: CGSize(width: 1280, height: 620), name: "drawer.png")
render(Desktop(size: CGSize(width: 1280, height: 300)) { drawer(.peek(store.reminders[1].id), store: store, progress: 0.35) },
       size: CGSize(width: 1280, height: 300), name: "reminder.png")
render(Desktop(size: CGSize(width: 1280, height: 200)) { drawer(.closed, store: store) },
       size: CGSize(width: 1280, height: 200), name: "closed.png")
render(AppIcon(), size: CGSize(width: 1024, height: 1024), name: "icon-1024.png")
