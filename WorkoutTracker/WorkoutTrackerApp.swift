import SwiftData
import SwiftUI

private struct AppStartupShellView: View {
    var body: some View {
        HStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppColors.accent)
                .scaleEffect(1.05)

            VStack(alignment: .leading, spacing: 4) {
                Text("Loading your workspace...")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)

                Text("Plans, today state, and your active session are hydrating in the background.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(maxWidth: 460, alignment: .leading)
        .appSurface(cornerRadius: 18, shadow: false)
        .accessibilityIdentifier("app.startupOverlay")
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
        let store = AppStore(
            modelContainer: container,
            launchArguments: launchArguments
        )

        modelContainer = container
        _appStore = State(
            initialValue: store
        )

        Task {
            await store.hydrateIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootAppView()
                .environment(appStore)
                .allowsHitTesting(appStore.isHydrated)
                .overlay(alignment: .top) {
                    if appStore.isHydrated == false {
                        AppStartupShellView()
                            .padding(.top, 12)
                            .padding(.horizontal, 12)
                            .allowsHitTesting(false)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeOut(duration: 0.2), value: appStore.isHydrated)
                .onChange(of: scenePhase, initial: false) { _, phase in
                    switch phase {
                    case .active:
                        guard appStore.isHydrated else {
                            return
                        }

                        appStore.syncRestTimerLiveActivity()
                        Task {
                            await appStore.refreshDerivedStores()
                        }

                    case .inactive, .background:
                        appStore.flushPendingSessionPersistence()
                        appStore.flushPendingPlanPersistence()

                    @unknown default:
                        break
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
