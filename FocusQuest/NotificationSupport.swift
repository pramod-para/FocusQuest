import UIKit
@preconcurrency import UserNotifications

enum ReminderNotificationSupport {
    static let categoryIdentifier = "ROUTINE_REMINDER"
    static let goalIDKey = "goalID"
    static let completeAction = "COMPLETE_GOAL"
    static let snoozeAction = "SNOOZE_GOAL_10"
    static let skipAction = "SKIP_GOAL_TODAY"

    static func registerCategories() {
        let complete = UNNotificationAction(
            identifier: completeAction,
            title: "Complete",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: snoozeAction,
            title: "Snooze 10 min",
            options: []
        )
        let skip = UNNotificationAction(
            identifier: skipAction,
            title: "Skip today",
            options: [.destructive]
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [complete, snooze, skip],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}

final class FocusQuestAppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        ReminderNotificationSupport.registerCategories()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let goalID = response.notification.request.content.userInfo[ReminderNotificationSupport.goalIDKey] as? String
        guard let goalID else {
            completionHandler()
            return
        }

        Task { @MainActor in
            switch actionIdentifier {
            case ReminderNotificationSupport.completeAction:
                RoutineStore.shared.completeGoal(id: goalID)
            case ReminderNotificationSupport.snoozeAction:
                await RoutineStore.shared.snooze(goalID: goalID)
            case ReminderNotificationSupport.skipAction:
                RoutineStore.shared.skipToday(goalID: goalID)
            default:
                break
            }
            completionHandler()
        }
    }
}
