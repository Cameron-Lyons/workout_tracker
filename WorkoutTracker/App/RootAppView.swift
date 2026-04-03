import Observation
import SwiftUI

struct RootAppView: View {
    @Environment(AppStore.self) private var appStore
    @State private var loggerPresentationSignpost: PerformanceSignpost.Interval?

    init() {
        AppAppearance.configureIfNeeded()
    }

    var body: some View {
        @Bindable var appStore = appStore

        Group {
            if appStore.isCompletingOnboarding {
                OnboardingSetupView()
            } else if appStore.shouldShowOnboarding {
                OnboardingView()
            } else {
                RootTabView()
                    .environment(appStore)
                    .environment(appStore.settingsStore)
                    .environment(appStore.plansStore)
                    .environment(appStore.sessionStore)
                    .environment(appStore.todayStore)
                    .environment(appStore.progressStore)
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { appStore.sessionStore.isPresentingSession },
                set: { isPresented in
                    if !isPresented {
                        appStore.sessionStore.dismissSessionPresentation()
                    }
                }
            )
        ) {
            ActiveSessionView(onDisplayed: endLoggerPresentationSignpost)
                .environment(appStore)
                .environment(appStore.settingsStore)
                .environment(appStore.plansStore)
                .environment(appStore.sessionStore)
        }
        .onChange(of: appStore.sessionStore.isPresentingSession, initial: false) { _, isPresenting in
            if isPresenting {
                loggerPresentationSignpost = PerformanceSignpost.begin("Logger Presentation")
            } else {
                endLoggerPresentationSignpost()
            }
        }
        .sheet(
            item: Binding(
                get: { appStore.sessionStore.lastFinishedSummary },
                set: { appStore.sessionStore.lastFinishedSummary = $0 }
            )
        ) { summary in
            SessionFinishSummaryView(summary: summary)
                .environment(appStore.settingsStore)
        }
        .alert(
            item: Binding(
                get: { appStore.persistenceStartupIssue },
                set: { issue in
                    if issue == nil {
                        appStore.dismissPersistenceStartupIssue()
                    }
                }
            )
        ) { issue in
            Alert(
                title: Text("\(issue.title)\n\n\(issue.message)"),
                dismissButton: .default(Text("OK")) {
                    appStore.dismissPersistenceStartupIssue()
                }
            )
        }
    }

    private func endLoggerPresentationSignpost() {
        guard let loggerPresentationSignpost else {
            return
        }

        PerformanceSignpost.end(loggerPresentationSignpost)
        self.loggerPresentationSignpost = nil
    }
}

private struct OnboardingSetupView: View {
    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppToneStyle.today.accent)

                VStack(spacing: 8) {
                    Text("Setting Up Your Programs")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Bringing your selected program into the app so Today is ready when it appears.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(28)
            .frame(maxWidth: 340)
            .appFeatureSurface(tone: .today)
        }
    }
}
