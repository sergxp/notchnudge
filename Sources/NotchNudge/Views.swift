import SwiftUI

enum Theme {
    static let accent = LinearGradient(colors: [Color(red: 1.0, green: 0.62, blue: 0.2), Color(red: 1.0, green: 0.33, blue: 0.45)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
    static let amber = Color(red: 1.0, green: 0.62, blue: 0.2)
    static let field = Color.white.opacity(0.07)
    static let dim = Color.white.opacity(0.45)
    static let faint = Color.white.opacity(0.28)
}

let intervalPresets: [(String, TimeInterval)] = [("1m", 60), ("5m", 300), ("15m", 900), ("30m", 1800), ("1h", 3600), ("2h", 7200)]

// MARK: - Shape: a black tab that grows out of the notch, with soft "ears" at the top corners.

struct NotchShape: Shape {
    var ear: CGFloat
    var bottom: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(ear, bottom) }
        set { ear = newValue.first; bottom = newValue.second }
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        let t = ear, b = bottom
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX + t, y: r.minY + t), control: CGPoint(x: r.minX + t, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + t, y: r.maxY - b))
        p.addQuadCurve(to: CGPoint(x: r.minX + t + b, y: r.maxY), control: CGPoint(x: r.minX + t, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - t - b, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - t, y: r.maxY - b), control: CGPoint(x: r.maxX - t, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - t, y: r.minY + t))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.maxX - t, y: r.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var c: NotchController

    var body: some View {
        ZStack(alignment: .top) {
            if c.mode == .open {
                Color.black.opacity(0.001).onTapGesture { c.close() }   // click empty space = close
            }
            drawer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }

    private var drawer: some View {
        let size = c.drawerSize
        let ear = c.earRadius
        let shape = NotchShape(ear: ear, bottom: c.mode == .closed ? 10 : 26)
        return ZStack(alignment: .top) {
            switch c.mode {
            case .open:
                DrawerView()
                    .frame(width: NotchController.openSize.width, height: NotchController.openSize.height, alignment: .top)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            case .peek(let id):
                PeekView(id: id)
                    .frame(width: c.peekSize.width, height: c.peekSize.height, alignment: .top)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            case .closed:
                EmptyView()
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .padding(.horizontal, ear)
        .background(shape.fill(Color.black))
        .clipShape(shape)
        .shadow(color: .black.opacity(c.mode == .closed ? 0 : 0.45), radius: 24, y: 12)
    }
}

// MARK: - Drawer (list + composer)

struct DrawerView: View {
    @EnvironmentObject var c: NotchController
    @EnvironmentObject var store: ReminderStore
    @State private var draft = ""
    @State private var interval: TimeInterval = 1800
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 14) {
            header
            composer
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1).padding(.horizontal, 18)
            list
            footer
        }
        .padding(.bottom, 14)
        .onAppear {
            if c.focusToken > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { focused = true } }
        }
        .onChange(of: c.focusToken) { focused = true }
    }

    // Sits beside the notch, using the dead space on either side.
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.fill").foregroundStyle(Theme.accent)
            Text("Nudges").font(.system(size: 13, weight: .semibold, design: .rounded))
            Spacer()
            Button { store.allPaused.toggle() } label: {
                Image(systemName: store.allPaused ? "bell.slash.fill" : "bell.badge")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(store.allPaused ? AnyShapeStyle(Theme.dim) : AnyShapeStyle(Theme.accent))
            }
            .buttonStyle(.plain)
            .help(store.allPaused ? "Resume all nudges" : "Pause all nudges")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .frame(height: c.notchSize.height)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill").font(.system(size: 16)).foregroundStyle(Theme.accent)
                TextField("", text: $draft, prompt: Text("Remind me to\u{2026}").foregroundColor(Theme.faint))
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .focused($focused)
                    .onSubmit(add)
                if !draft.isEmpty {
                    Button(action: add) {
                        Text("Add").font(.system(size: 12, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Capsule().fill(Theme.accent))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.field))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(focused ? AnyShapeStyle(Theme.accent.opacity(0.7)) : AnyShapeStyle(Color.clear), lineWidth: 1))
            .animation(.easeOut(duration: 0.15), value: draft.isEmpty)

            HStack(spacing: 6) {
                Text("Every").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Theme.dim)
                ForEach(intervalPresets, id: \.1) { label, secs in
                    Button { withAnimation(.easeOut(duration: 0.15)) { interval = secs } } label: {
                        Text(label)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(interval == secs ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.field)))
                            .foregroundStyle(interval == secs ? .white : Theme.dim)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 18)
    }

    @ViewBuilder private var list: some View {
        if store.reminders.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "sparkles").font(.system(size: 26)).foregroundStyle(Theme.accent)
                Text("Nothing to nudge you about yet").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Theme.dim)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(store.reminders) { r in
                        ReminderRow(reminder: r)
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                    }
                }
                .padding(.horizontal, 10)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var footer: some View {
        HStack {
            if let next = store.upNext {
                Text("Next: ").foregroundStyle(Theme.faint) +
                Text(next.text).foregroundStyle(Theme.dim) +
                Text("  in \(shortDuration(next.nextFire.timeIntervalSince(store.now)))").foregroundStyle(Theme.amber)
            } else {
                Text(store.allPaused ? "All nudges paused" : "No active nudges").foregroundStyle(Theme.faint)
            }
            Spacer()
            Text("\u{2303}\u{2325}N").foregroundStyle(Theme.faint)
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .lineLimit(1)
        .padding(.horizontal, 22)
    }

    private func add() {
        guard !draft.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { store.add(draft, every: interval) }
        draft = ""
    }
}

struct ReminderRow: View {
    @EnvironmentObject var c: NotchController
    @EnvironmentObject var store: ReminderStore
    let reminder: Reminder
    @State private var hovering = false

    var body: some View {
        let remaining = reminder.nextFire.timeIntervalSince(store.now)
        let inactive = reminder.isPaused || store.allPaused
        let progress = inactive ? 0 : 1 - max(0, min(1, remaining / reminder.interval))

        HStack(spacing: 12) {
            ProgressRing(progress: progress, paused: inactive).frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(reminder.text)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(inactive ? Theme.dim : .white)
                    .lineLimit(2)
                Text(inactive ? "every \(shortDuration(reminder.interval)) \u{00B7} paused"
                              : "every \(shortDuration(reminder.interval)) \u{00B7} in \(shortDuration(remaining))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.faint)
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            if hovering {
                HStack(spacing: 4) {
                    iconButton("eye", help: "Show now") { c.showNow(reminder.id) }
                    iconButton(reminder.isPaused ? "play.fill" : "pause.fill", help: reminder.isPaused ? "Resume" : "Pause") {
                        store.togglePause(reminder.id)
                    }
                    iconButton("trash", help: "Delete") {
                        withAnimation(.easeOut(duration: 0.2)) { store.delete(reminder.id) }
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(hovering ? Color.white.opacity(0.06) : .clear))
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
    }

    private func iconButton(_ name: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.field))
                .foregroundStyle(Theme.dim)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct ProgressRing: View {
    var progress: Double
    var paused: Bool

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(paused ? AnyShapeStyle(Theme.dim) : AnyShapeStyle(Theme.accent),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
            if paused {
                Image(systemName: "pause.fill").font(.system(size: 7, weight: .bold)).foregroundStyle(Theme.dim)
            }
        }
    }
}

// MARK: - Peek (the timed pop-down)

struct PeekView: View {
    @EnvironmentObject var c: NotchController
    @EnvironmentObject var store: ReminderStore
    let id: UUID
    @State private var bounce = 0

    var body: some View {
        let r = store.reminder(id)
        VStack(spacing: 0) {
            Spacer().frame(height: c.notchSize.height)
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.accent).frame(width: 44, height: 44)
                        .shadow(color: Theme.amber.opacity(0.6), radius: 12)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: bounce)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("REMINDER").font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1.2).foregroundStyle(Theme.amber)
                    Text(r?.text ?? "").font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.white).lineLimit(2)
                    if let r {
                        Text("every \(shortDuration(r.interval))").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(Theme.faint)
                    }
                }
                Spacer(minLength: 6)
                VStack(spacing: 6) {
                    Button { c.dismissPeek() } label: {
                        Text("Got it").font(.system(size: 12, weight: .bold, design: .rounded))
                            .frame(width: 84, height: 26)
                            .background(Capsule().fill(Theme.accent))
                            .foregroundStyle(.white)
                    }.buttonStyle(.plain)
                    Button { c.dismissPeek(snooze: 600) } label: {
                        Text("Snooze 10m").font(.system(size: 12, weight: .semibold, design: .rounded))
                            .frame(width: 84, height: 26)
                            .background(Capsule().fill(Theme.field))
                            .foregroundStyle(Theme.dim)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .frame(maxHeight: .infinity)

            // Time left before it tucks itself away.
            GeometryReader { g in
                Capsule().fill(Theme.accent)
                    .frame(width: g.size.width * (1 - c.peekProgress), height: 2)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(height: 2)
            .padding(.horizontal, 28)
            .padding(.bottom, 8)
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { bounce += 1 } }
    }
}
