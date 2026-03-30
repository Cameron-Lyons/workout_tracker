import SwiftUI

struct RootTabView: View {
    @Environment(AppStore.self) private var appStore

    private enum Tab: String, Hashable {
        case today
        case plans
        case progress

        static var launchSelection: Tab? {
            let arguments = ProcessInfo.processInfo.arguments
            guard let flagIndex = arguments.firstIndex(of: "-codex-initial-tab"),
                arguments.indices.contains(flagIndex + 1)
            else {
                return nil
            }

            return Tab(rawValue: arguments[flagIndex + 1].lowercased())
        }
    }

    @State private var selectedTab: Tab
    @State private var progressSelectionSignpost: PerformanceSignpost.Interval?

    init() {
        _selectedTab = State(initialValue: Tab.launchSelection ?? .today)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tag(Tab.today)
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }

            PlansView()
                .tag(Tab.plans)
                .tabItem {
                    Label("Plans", systemImage: "list.bullet.rectangle")
                }

            ProgressDashboardView(onDisplayed: endProgressSelectionSignpost)
                .tag(Tab.progress)
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
        .tint(AppColors.accent)
        .task {
            await appStore.preloadDeferredTabDataIfNeeded(priority: .utility)
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .progress {
                progressSelectionSignpost = PerformanceSignpost.begin("Progress Tab Selection")
            } else {
                endProgressSelectionSignpost()
            }
        }
    }

    private func endProgressSelectionSignpost() {
        guard let progressSelectionSignpost else {
            return
        }

        PerformanceSignpost.end(progressSelectionSignpost)
        self.progressSelectionSignpost = nil
    }
}
