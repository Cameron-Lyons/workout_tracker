import SwiftUI

@main
struct WorkoutTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = WorkoutStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background || phase == .inactive {
                        store.flushPendingSaves()
                    }
                }
        }
    }
}
