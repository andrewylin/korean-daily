import Foundation
import UserNotifications

enum Scheduler {
    /// iOS keeps at most 64 pending local notifications, so we schedule 60
    /// and top the queue up every time the app opens.
    static let maxPending = 60
    static let maxAPICallsPerRun = 20

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func reschedule(store: WordStore) async {
        let d = UserDefaults.standard
        let start = d.object(forKey: Keys.startHour) as? Int ?? 8
        let end = d.object(forKey: Keys.endHour) as? Int ?? 21
        let interval = max(15, d.object(forKey: Keys.intervalMinutes) as? Int ?? 120)
        let useAPI = d.bool(forKey: Keys.useAPI)
        let apiKey = useAPI ? Keychain.get() : nil

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let times = fireTimes(start: start, end: end, interval: interval, limit: maxPending)
        let picks = store.pickWords(count: times.count)
        var apiBudget = maxAPICallsPerRun

        for (date, word) in zip(times, picks) {
            var entry = store.bundledEntry(word)

            // Hybrid: mix in fresh sentences for about half the slots,
            // and for any word with no bundled sentence.
            if let key = apiKey, apiBudget > 0, (entry == nil || Bool.random()) {
                if let fresh = try? await ClaudeClient.entry(for: word, apiKey: key) {
                    entry = fresh
                    apiBudget -= 1
                }
            }
            guard let entry else { continue }

            let content = UNMutableNotificationContent()
            content.title = entry.ko
            content.subtitle = "\(word.ko) = \(word.en)"
            content.body = entry.en
            content.sound = .default
            content.userInfo = ["word": word.ko]

            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: UUID().uuidString, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func fireTimes(start: Int, end: Int, interval: Int, limit: Int) -> [Date] {
        let cal = Calendar.current
        let now = Date()
        var out: [Date] = []
        for day in 0..<30 {
            guard let base = cal.date(byAdding: .day, value: day,
                                      to: cal.startOfDay(for: now)) else { continue }
            var minute = start * 60
            while minute <= end * 60 {
                if let t = cal.date(byAdding: .minute, value: minute, to: base), t > now {
                    out.append(t)
                    if out.count >= limit { return out }
                }
                minute += interval
            }
        }
        return out
    }
}
