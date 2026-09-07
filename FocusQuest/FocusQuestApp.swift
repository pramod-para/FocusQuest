import SwiftUI

@main
struct FocusQuestApp: App {
    @UIApplicationDelegateAdaptor(FocusQuestAppDelegate.self) private var appDelegate
    @StateObject private var store = RoutineStore.shared
    @StateObject private var health = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(health)
                .tint(.indigo)
        }
    }
}
