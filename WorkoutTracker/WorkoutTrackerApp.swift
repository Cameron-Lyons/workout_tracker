import SwiftUI

@main
struct WorkoutTrackerApp: App {
    @StateObject private var store = WorkoutStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
        }
    }
}
