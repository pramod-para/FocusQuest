import SwiftUI

@main
struct FocusQuestWatchApp: App {
    @StateObject private var store = WatchRoutineStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .tint(.indigo)
        }
    }
}
