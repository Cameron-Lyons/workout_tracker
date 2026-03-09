import SwiftData
import SwiftUI

private struct AppStartupShellView: View {
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(AppColors.accent)
                    .scaleEffect(1.2)

                Text("Loading session-first workspace...")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 24)
            .appSurface(cornerRadius: 16, shadow: false)
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
    }
}

@main
struct WorkoutTrackerApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer
    @State private var appStore: AppStore

    init() {
        let launchArguments = Set(ProcessInfo.processInfo.arguments)
        let useInMemoryStore = launchArguments.contains("--uitesting-in-memory")
        let container = WorkoutModelContainerFactory.makeContainer(
            isStoredInMemoryOnly: useInMemoryStore
        )

        modelContainer = container
        _appStore = State(
            initialValue: AppStore(
                modelContainer: container,
                launchArguments: launchArguments
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appStore.isHydrated {
                    RootAppView()
                        .environment(appStore)
                } else {
                    AppStartupShellView()
                }
            }
            .task {
                await appStore.hydrateIfNeeded()
            }
            .onChange(of: scenePhase, initial: false) { _, phase in
                if phase == .active {
                    Task {
                        await appStore.refreshDerivedStores()
                    }
                }
            }
        }
        .modelContainer(modelContainer)
    }
}
