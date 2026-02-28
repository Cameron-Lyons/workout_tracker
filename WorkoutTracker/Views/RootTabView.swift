import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            RoutinesView()
                .tabItem {
                    Label("Routines", systemImage: "list.bullet.clipboard")
                }

            WorkoutLoggerView()
                .tabItem {
                    Label("Log", systemImage: "figure.strengthtraining.traditional")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
        }
    }
}
