import Foundation
import Combine

struct Reminder: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var interval: TimeInterval          // seconds between nudges
    var nextFire: Date
    var isPaused = false
    var timesShown = 0
}

/// Holds reminders, saves them to disk, and decides which one is due.
final class ReminderStore: ObservableObject {
    @Published var reminders: [Reminder] = [] { didSet { save() } }
    @Published var allPaused: Bool = UserDefaults.standard.bool(forKey: "allPaused") {
        didSet {
            UserDefaults.standard.set(allPaused, forKey: "allPaused")
            if !allPaused { restartOverdue() }
        }
    }
    /// Ticks once a second so countdowns in the UI refresh.
    @Published var now = Date()

    private let fileURL: URL

    /// Pass a fileURL to keep data somewhere else (used by the screenshot tool so it never touches real reminders).
    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("NotchNudge", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("reminders.json")
        }
        load()
    }

    // MARK: Editing

    func add(_ text: String, every interval: TimeInterval) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        reminders.insert(Reminder(text: clean, interval: interval, nextFire: Date().addingTimeInterval(interval)), at: 0)
    }

    func rename(_ id: UUID, to text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let i = index(id), !clean.isEmpty else { return }
        reminders[i].text = clean
    }

    /// New timing restarts the countdown from now.
    func setInterval(_ id: UUID, _ interval: TimeInterval) {
        guard let i = index(id), interval >= 60 else { return }
        reminders[i].interval = interval
        reminders[i].nextFire = Date().addingTimeInterval(interval)
    }

    func delete(_ id: UUID) { reminders.removeAll { $0.id == id } }

    func togglePause(_ id: UUID) {
        guard let i = index(id) else { return }
        reminders[i].isPaused.toggle()
        if !reminders[i].isPaused { reminders[i].nextFire = Date().addingTimeInterval(reminders[i].interval) }
    }

    func snooze(_ id: UUID, for seconds: TimeInterval) {
        guard let i = index(id) else { return }
        reminders[i].nextFire = Date().addingTimeInterval(seconds)
    }

    /// Called the moment a reminder is shown: count it and book the next time.
    func markShown(_ id: UUID) {
        guard let i = index(id) else { return }
        reminders[i].timesShown += 1
        reminders[i].nextFire = Date().addingTimeInterval(reminders[i].interval)
    }

    // MARK: Queries

    func reminder(_ id: UUID) -> Reminder? { reminders.first { $0.id == id } }

    func due(at date: Date = Date()) -> Reminder? {
        guard !allPaused else { return nil }
        return reminders.filter { !$0.isPaused && $0.nextFire <= date }.min { $0.nextFire < $1.nextFire }
    }

    var upNext: Reminder? {
        guard !allPaused else { return nil }
        return reminders.filter { !$0.isPaused }.min { $0.nextFire < $1.nextFire }
    }

    // MARK: Private

    private func index(_ id: UUID) -> Int? { reminders.firstIndex { $0.id == id } }

    /// After a long pause, don't dump every overdue reminder at once.
    private func restartOverdue() {
        let t = Date()
        for i in reminders.indices where reminders[i].nextFire < t {
            reminders[i].nextFire = t.addingTimeInterval(reminders[i].interval)
        }
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Reminder].self, from: data) {
            reminders = saved
            restartOverdue()
        } else {
            let t = Date()
            reminders = [
                Reminder(text: "Drink some water", interval: 30 * 60, nextFire: t.addingTimeInterval(30 * 60)),
                Reminder(text: "Stand up and stretch for a minute", interval: 60 * 60, nextFire: t.addingTimeInterval(60 * 60)),
            ]
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// "30m", "1h", "1h 30m", "45s"
func shortDuration(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds.rounded()))
    if s < 60 { return "\(s)s" }
    let m = s / 60
    if m < 60 { return "\(m)m" }
    let h = m / 60, rem = m % 60
    return rem == 0 ? "\(h)h" : "\(h)h \(rem)m"
}
