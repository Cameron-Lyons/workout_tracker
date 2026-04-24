import SwiftUI

struct ActiveSessionHeaderState: Equatable {
    var templateName: String
    var startedAtLabel: String
    var progress: ActiveSessionProgress
    var restTimerEndsAt: Date?
}

struct ActiveSessionDisplaySettings: Equatable {
    var weightUnit: WeightUnit
}

struct ActiveSessionActions {
    var addSet: (UUID) -> Void
    var copyLastSet: (UUID) -> Void
    var updateWeight: (UUID, UUID, Double) -> Void
    var updateReps: (UUID, UUID, Int) -> Void
    var toggleSetCompletion: (UUID, UUID) -> Void
    var clearRest: () -> Void
    var finishWorkout: () -> Void
}

enum ActiveSessionViewMetrics {
    static let detailedChromeRevealDelayNanoseconds: UInt64 = 120_000_000
}

struct ActiveSessionRestTimerPresentation {
    let tone: AppToneStyle
    let label: String
    let eyebrow: String
    let subtitle: String

    init(endDate: Date?, now: Date) {
        guard let endDate else {
            tone = .today
            label = "Off"
            eyebrow = "Active Session"
            subtitle = "Tap complete to auto-start rest timers, then edit each set directly."
            return
        }

        let remaining = max(0, Int(endDate.timeIntervalSince(now)))
        if remaining == 0 {
            tone = .success
            label = "Ready"
            eyebrow = "Next Set Ready"
            subtitle = "Rest timer complete. Start the next set whenever you are ready."
            return
        }

        let durationText = Self.durationText(remaining)
        tone = .warning
        label = durationText
        eyebrow = "Rest Timer Live"
        subtitle = "Rest timer running: \(durationText) remaining."
    }

    private static func durationText(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

struct ActiveSessionView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(PlansStore.self) private var plansStore
    @Environment(SessionStore.self) private var sessionStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    var onDisplayed: (() -> Void)?

    @State private var showingAddExerciseSheet = false
    @State private var showsDetailedChrome = false
    @State private var chromeRevealTask: Task<Void, Never>?

    private var draft: SessionDraft? {
        sessionStore.activeDraft
    }

    private var headerState: ActiveSessionHeaderState? {
        guard let draft else {
            return nil
        }

        return ActiveSessionHeaderState(
            templateName: draft.templateNameSnapshot,
            startedAtLabel: draft.startedAt.formatted(date: .omitted, time: .shortened),
            progress: sessionStore.activeDraftProgress,
            restTimerEndsAt: draft.restTimerEndsAt
        )
    }

    private var displaySettings: ActiveSessionDisplaySettings {
        ActiveSessionDisplaySettings(
            weightUnit: settingsStore.weightUnit
        )
    }

    private var actions: ActiveSessionActions {
        ActiveSessionActions(
            addSet: { appStore.send(.addSet(blockID: $0)) },
            copyLastSet: { appStore.send(.copyLastSet(blockID: $0)) },
            updateWeight: { blockID, setID, weight in
                appStore.send(.updateSetWeight(blockID: blockID, setID: setID, weight: weight))
            },
            updateReps: { blockID, setID, reps in
                appStore.send(.updateSetReps(blockID: blockID, setID: setID, reps: reps))
            },
            toggleSetCompletion: { blockID, setID in
                appStore.send(.toggleSetCompletion(blockID: blockID, setID: setID))
            },
            clearRest: { appStore.send(.clearRestTimer) },
            finishWorkout: {
                if appStore.send(.finishActiveSession) {
                    dismiss()
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if let draft, let headerState {
                    ActiveSessionContentView(
                        headerState: headerState,
                        exercises: draft.exercises,
                        displaySettings: displaySettings,
                        actions: actions,
                        showsDetailedChrome: showsDetailedChrome
                    )
                } else {
                    AppEmptyStateCard(
                        systemImage: "figure.cooldown",
                        title: "No active session",
                        message: "Start a workout from Today or Programs.",
                        tone: .today
                    )
                }
            }
            .navigationTitle(draft.map(\.templateNameSnapshot) ?? "Session")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        appStore.sessionStore.dismissSessionPresentation()
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Undo") {
                        appStore.send(.undoSessionMutation)
                    }
                    .disabled(sessionStore.canUndo == false)

                    Button("Add Exercise") {
                        showingAddExerciseSheet = true
                    }

                    Button("Discard", role: .destructive) {
                        appStore.send(.discardActiveSession)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddExerciseSheet) {
                ExercisePickerSheet(
                    catalog: plansStore.catalog,
                    title: "Add Exercise",
                    onPick: { exercise in
                        appStore.send(.addExerciseToActiveSession(exerciseID: exercise.id))
                    },
                    onCreateCustom: { customName in
                        appStore.send(.addCustomExerciseToActiveSession(name: customName))
                    }
                )
            }
            .onAppear {
                onDisplayed?()
                scheduleDetailedChromeReveal()
            }
            .onDisappear {
                chromeRevealTask?.cancel()
                chromeRevealTask = nil
                showsDetailedChrome = false
            }
        }
    }

    private func scheduleDetailedChromeReveal() {
        guard showsDetailedChrome == false else {
            return
        }

        chromeRevealTask?.cancel()
        chromeRevealTask = Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(nanoseconds: ActiveSessionViewMetrics.detailedChromeRevealDelayNanoseconds)
            guard !Task.isCancelled else {
                return
            }

            showsDetailedChrome = true
        }
    }
}
