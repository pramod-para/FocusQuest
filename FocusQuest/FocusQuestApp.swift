import SwiftUI

@main
struct FocusQuestApp: App {
    @StateObject private var store = RoutineStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(.indigo)
        }
    }
}
