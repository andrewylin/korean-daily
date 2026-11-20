import SwiftUI
import UserNotifications

final class NotifDelegate: NSObject, UNUserNotificationCenterDelegate {
    // Show the banner even when the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@main
struct KoreanDailyApp: App {
    static let delegate = NotifDelegate()
    @StateObject private var store = WordStore()

    init() {
        UNUserNotificationCenter.current().delegate = KoreanDailyApp.delegate
    }

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
        }
    }
}
