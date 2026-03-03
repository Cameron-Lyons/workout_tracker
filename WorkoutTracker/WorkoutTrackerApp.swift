import SwiftUI
import SwiftData

private struct AppStartupShellView: View {
    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 14) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(AppColors.accent)
                    .scaleEffect(1.2)

                Text("Loading workout data...")
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
    @StateObject private var store: WorkoutStore

    init() {
        let container = WorkoutModelContainerFactory.makeContainer()
        modelContainer = container
        _store = StateObject(wrappedValue: WorkoutStore(modelContainer: container))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if store.isHydrated {
                    RootTabView()
                } else {
                    AppStartupShellView()
                }
            }
                .environmentObject(store)
                .task {
                    store.startHydrationIfNeeded()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background || phase == .inactive {
                        store.flushPendingSaves()
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
