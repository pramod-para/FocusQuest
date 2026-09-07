import SwiftUI

@main
struct FocusQuestApp: App {
    @UIApplicationDelegateAdaptor(FocusQuestAppDelegate.self) private var appDelegate
    @StateObject private var store = RoutineStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(.indigo)
        }
    }
}
