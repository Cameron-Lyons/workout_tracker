import Foundation
import SwiftUI

private struct SetDraft: Identifiable, Equatable {
    var id = UUID()
    var weight = ""
    var reps = ""
    var transcript = ""
    var prescriptionNote: String?
}

private struct ActiveVoiceTarget: Equatable {
    var exerciseID: UUID
    var setID: UUID
}

struct WorkoutLoggerView: View {
    private enum Constants {
        static let weightInputCharacters = "0123456789."
        static let savedToastDuration = 1.4
        static let defaultRestSeconds = 90
        static let minimumRestSeconds = 1
        static let quickAddRestSeconds = 30
        static let restPresets = [60, 90, 120, 180]
        static let restTickerInterval = 1.0
        static let animationDuration = 0.2
    }

    private enum Layout {
        static let rootSpacing: CGFloat = 16
        static let sectionSpacing: CGFloat = 12
        static let compactSpacing: CGFloat = 8
        static let rowSpacing: CGFloat = 10
        static let cardCornerRadius: CGFloat = 16
        static let setCardCornerRadius: CGFloat = 12
        static let setCardPadding: CGFloat = 10
        static let listBottomPadding: CGFloat = 6
        static let toastHorizontalPadding: CGFloat = 14
        static let toastVerticalPadding: CGFloat = 10
        static let toastBottomPadding: CGFloat = 24
    }

    @EnvironmentObject private var store: WorkoutStore
    @StateObject private var speechInput = SpeechInputManager()
    @AppStorage("workout_tracker_rest_timer_auto_start_v1") private var autoStartRestTimer = false

    @State private var selectedRoutineID: UUID?
    @State private var drafts: [UUID: [SetDraft]] = [:]
    @State private var activeVoiceTarget: ActiveVoiceTarget?

    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    @State private var showSavedToast = false
    @State private var showVoiceTools = false

    @State private var restTimerDuration = Constants.defaultRestSeconds
    @State private var restTimerRemaining = 0
    @State private var isRestTimerRunning = false

    private let restTicker = Timer.publish(
        every: Constants.restTickerInterval,
        on: .main,
        in: .common
    ).autoconnect()

    private var selectedRoutine: Routine? {
        guard let selectedRoutineID else { return nil }
        return store.routines.first { $0.id == selectedRoutineID }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Layout.rootSpacing) {
                let selectedRoutineWithPlan = selectedRoutine.map { routine in
                    (routine: routine, plan: WorkoutProgramEngine.plan(for: routine))
                }

                routineSelector

                if let contextLabel = selectedRoutineWithPlan?.plan.contextLabel {
                    Text(contextLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("Manual entry is primary. Enable voice tools only if you want quick dictation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)

                restTimerCard
                    .padding(.horizontal)

                if let selectedRoutineWithPlan {
                    let routine = selectedRoutineWithPlan.routine
                    let plan = selectedRoutineWithPlan.plan

                    ScrollView {
                        LazyVStack(spacing: Layout.sectionSpacing) {
                            ForEach(activeExercises(in: routine, plan: plan)) { exercise in
                                exerciseCard(exercise, plan: plan)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, Layout.listBottomPadding)
                    }

                    Button {
                        saveWorkout(routine: routine, plan: plan)
                    } label: {
                        Text("Save Workout")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .padding(.bottom)
                    .disabled(!hasAnyLoggedValues(in: routine, plan: plan))
                } else {
                    Spacer()
                    ContentUnavailableView(
                        "No Routine Selected",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Create a routine first, then pick it here to start logging.")
                    )
                    Spacer()
                }
            }
            .navigationTitle("Log Workout")
            .onAppear(perform: syncSelection)
            .onChange(of: store.routines) { _, _ in
                syncSelection()
            }
            .onChange(of: selectedRoutineID) { _, _ in
                rebuildDrafts()
            }
            .onChange(of: showVoiceTools) { _, isEnabled in
                if !isEnabled {
                    speechInput.stopRecording()
                    activeVoiceTarget = nil
                }
            }
            .onReceive(restTicker) { _ in
                handleRestTimerTick()
            }
            .alert("Voice Input", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showVoiceTools.toggle()
                    } label: {
                        Label(showVoiceTools ? "Voice On" : "Voice Off", systemImage: showVoiceTools ? "mic.fill" : "mic.slash")
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showSavedToast {
                    Text("Workout saved")
                        .padding(.horizontal, Layout.toastHorizontalPadding)
                        .padding(.vertical, Layout.toastVerticalPadding)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, Layout.toastBottomPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: Constants.animationDuration), value: showSavedToast)
        }
    }

    private var routineSelector: some View {
        Picker("Routine", selection: $selectedRoutineID) {
            Text("Choose Routine").tag(Optional<UUID>.none)
            ForEach(store.routines) { routine in
                Text(routine.name).tag(Optional(routine.id))
            }
        }
        .pickerStyle(.menu)
        .padding(.horizontal)
    }

    private var restTimerCard: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            HStack {
                Label("Rest Timer", systemImage: "timer")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(restTimerDisplay)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(restTimerRemaining == 0 && !isRestTimerRunning ? .secondary : .primary)
            }

            ProgressView(value: restProgress)
                .tint(restTimerRemaining == 0 ? .green : .blue)

            HStack(spacing: Layout.compactSpacing) {
                ForEach(Constants.restPresets, id: \.self) { seconds in
                    Button(presetLabel(for: seconds)) {
                        startRestTimer(seconds: seconds)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }

            HStack(spacing: Layout.rowSpacing) {
                Button {
                    if isRestTimerRunning {
                        pauseRestTimer()
                    } else if restTimerRemaining > 0 {
                        resumeRestTimer()
                    } else {
                        startRestTimer(seconds: restTimerDuration)
                    }
                } label: {
                    Label(restControlLabel, systemImage: restControlIcon)
                }
                .buttonStyle(.borderedProminent)

                Button("+30s") {
                    addRestTime(seconds: Constants.quickAddRestSeconds)
                }
                .buttonStyle(.bordered)

                Button("Reset", role: .destructive) {
                    resetRestTimer()
                }
                .buttonStyle(.bordered)
                .disabled(restTimerRemaining == 0 && !isRestTimerRunning)
            }

            if restTimerRemaining == 0 && !isRestTimerRunning {
                Text("Ready for your next set.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Auto-start after saving workout", isOn: $autoStartRestTimer)
                .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
        )
    }

    private func exerciseCard(
        _ exercise: Exercise,
        plan: ProgramWorkoutPlan
    ) -> some View {
        let sets = setDrafts(for: exercise.id, plan: plan)

        return VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            Text(exercise.name)
                .font(.headline)

            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                VStack(alignment: .leading, spacing: Layout.compactSpacing) {
                    HStack {
                        Text("Set \(index + 1)")
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        if sets.count > 1 {
                            Button(role: .destructive) {
                                removeSet(from: exercise.id, setID: set.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: Layout.rowSpacing) {
                        TextField("Weight", text: weightBinding(for: exercise.id, setID: set.id))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)

                        TextField("Reps", text: repsBinding(for: exercise.id, setID: set.id))
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }

                    if let note = set.prescriptionNote, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if showVoiceTools {
                        HStack(spacing: Layout.rowSpacing) {
                            Button {
                                toggleVoiceInput(for: exercise.id, setID: set.id)
                            } label: {
                                Label(
                                    isVoiceActive(for: exercise.id, setID: set.id) && speechInput.isRecording ? "Stop" : "Speak",
                                    systemImage: isVoiceActive(for: exercise.id, setID: set.id) && speechInput.isRecording ? "stop.circle.fill" : "mic.fill"
                                )
                            }
                            .buttonStyle(.bordered)
                            .tint(isVoiceActive(for: exercise.id, setID: set.id) && speechInput.isRecording ? .red : .blue)

                            if !set.transcript.isEmpty {
                                Text("Heard: \(set.transcript)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .padding(Layout.setCardPadding)
                .background(
                    Color(uiColor: .tertiarySystemBackground),
                    in: RoundedRectangle(cornerRadius: Layout.setCardCornerRadius)
                )
            }

            Button {
                addSet(to: exercise.id)
            } label: {
                Label("Add Set", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
        )
    }

    private func activeExercises(in routine: Routine, plan: ProgramWorkoutPlan) -> [Exercise] {
        if let activeIDs = plan.activeExerciseIDs {
            return routine.exercises.filter { activeIDs.contains($0.id) }
        }

        return routine.exercises
    }

    private var restControlLabel: String {
        if isRestTimerRunning {
            return "Pause"
        }

        if restTimerRemaining > 0 {
            return "Resume"
        }

        return "Start"
    }

    private var restControlIcon: String {
        isRestTimerRunning ? "pause.fill" : "play.fill"
    }

    private var restProgress: Double {
        guard restTimerDuration > 0 else { return 0 }
        let elapsed = Double(restTimerDuration - restTimerRemaining)
        return max(0, min(1, elapsed / Double(restTimerDuration)))
    }

    private var restTimerDisplay: String {
        durationText(from: restTimerRemaining)
    }

    private func presetLabel(for seconds: Int) -> String {
        durationText(from: seconds)
    }

    private func durationText(from totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }

    private func startRestTimer(seconds: Int) {
        let safeSeconds = max(seconds, Constants.minimumRestSeconds)
        restTimerDuration = safeSeconds
        restTimerRemaining = safeSeconds
        isRestTimerRunning = true
    }

    private func pauseRestTimer() {
        isRestTimerRunning = false
    }

    private func resumeRestTimer() {
        if restTimerRemaining == 0 {
            restTimerRemaining = restTimerDuration
        }
        isRestTimerRunning = true
    }

    private func resetRestTimer() {
        isRestTimerRunning = false
        restTimerRemaining = 0
    }

    private func addRestTime(seconds: Int) {
        guard seconds > 0 else { return }

        if restTimerRemaining == 0 {
            startRestTimer(seconds: seconds)
            return
        }

        restTimerRemaining += seconds
        restTimerDuration = max(restTimerDuration, restTimerRemaining)
    }

    private func handleRestTimerTick() {
        guard isRestTimerRunning, restTimerRemaining > 0 else { return }

        restTimerRemaining -= 1
        if restTimerRemaining <= 0 {
            restTimerRemaining = 0
            isRestTimerRunning = false
        }
    }

    private func defaultDrafts(
        for exerciseID: UUID,
        plan: ProgramWorkoutPlan
    ) -> [SetDraft] {
        let templates = plan.setTemplatesByExerciseID[exerciseID] ?? []

        if templates.isEmpty {
            return [SetDraft()]
        }

        return templates.map { template in
            SetDraft(
                weight: template.weight.map(WeightFormatter.displayString) ?? "",
                reps: String(template.reps),
                transcript: "",
                prescriptionNote: template.note
            )
        }
    }

    private func syncSelection() {
        if selectedRoutineID == nil {
            selectedRoutineID = store.routines.first?.id
        }

        if let selectedRoutineID,
           store.routines.contains(where: { $0.id == selectedRoutineID }) == false {
            self.selectedRoutineID = store.routines.first?.id
        }

        rebuildDrafts()
    }

    private func rebuildDrafts() {
        guard let routine = selectedRoutine else {
            drafts = [:]
            return
        }

        let plan = WorkoutProgramEngine.plan(for: routine)
        let exercises = activeExercises(in: routine, plan: plan)
        var refreshed: [UUID: [SetDraft]] = [:]

        for exercise in exercises {
            let existingSets = drafts[exercise.id] ?? []
            refreshed[exercise.id] = existingSets.isEmpty
                ? defaultDrafts(for: exercise.id, plan: plan)
                : existingSets
        }

        drafts = refreshed

        if let activeVoiceTarget,
           refreshed[activeVoiceTarget.exerciseID]?.contains(where: { $0.id == activeVoiceTarget.setID }) != true {
            speechInput.stopRecording()
            self.activeVoiceTarget = nil
        }
    }

    private func setDrafts(
        for exerciseID: UUID,
        plan: ProgramWorkoutPlan
    ) -> [SetDraft] {
        let sets = drafts[exerciseID] ?? []
        return sets.isEmpty ? defaultDrafts(for: exerciseID, plan: plan) : sets
    }

    private func addSet(to exerciseID: UUID) {
        var sets = drafts[exerciseID] ?? []
        if sets.isEmpty {
            sets = [SetDraft()]
        }

        sets.append(SetDraft())
        drafts[exerciseID] = sets
    }

    private func removeSet(from exerciseID: UUID, setID: UUID) {
        guard var sets = drafts[exerciseID],
              let index = sets.firstIndex(where: { $0.id == setID }) else {
            return
        }

        if isVoiceActive(for: exerciseID, setID: setID) {
            speechInput.stopRecording()
            activeVoiceTarget = nil
        }

        sets.remove(at: index)
        drafts[exerciseID] = sets.isEmpty ? [SetDraft()] : sets
    }

    private func updateSet(
        for exerciseID: UUID,
        setID: UUID,
        update: (inout SetDraft) -> Void
    ) {
        guard var sets = drafts[exerciseID],
              let index = sets.firstIndex(where: { $0.id == setID }) else {
            return
        }

        update(&sets[index])
        drafts[exerciseID] = sets
    }

    private func weightBinding(for exerciseID: UUID, setID: UUID) -> Binding<String> {
        Binding(
            get: {
                drafts[exerciseID]?.first(where: { $0.id == setID })?.weight ?? ""
            },
            set: { value in
                updateSet(for: exerciseID, setID: setID) { set in
                    set.weight = value.filter { Constants.weightInputCharacters.contains($0) }
                }
            }
        )
    }

    private func repsBinding(for exerciseID: UUID, setID: UUID) -> Binding<String> {
        Binding(
            get: {
                drafts[exerciseID]?.first(where: { $0.id == setID })?.reps ?? ""
            },
            set: { value in
                updateSet(for: exerciseID, setID: setID) { set in
                    set.reps = value.filter(\.isNumber)
                }
            }
        )
    }

    private func isVoiceActive(for exerciseID: UUID, setID: UUID) -> Bool {
        activeVoiceTarget == ActiveVoiceTarget(exerciseID: exerciseID, setID: setID)
    }

    private func toggleVoiceInput(for exerciseID: UUID, setID: UUID) {
        let target = ActiveVoiceTarget(exerciseID: exerciseID, setID: setID)

        if activeVoiceTarget == target && speechInput.isRecording {
            speechInput.stopRecording()
            activeVoiceTarget = nil
            return
        }

        speechInput.requestPermissions { granted in
            guard granted else {
                errorMessage = SpeechInputError.permissionsDenied.localizedDescription
                showErrorAlert = true
                return
            }

            do {
                activeVoiceTarget = target

                try speechInput.startRecording { transcript, isFinal in
                    updateSet(for: exerciseID, setID: setID) { set in
                        set.transcript = transcript

                        let parsed = VoiceParser.parseWeightAndReps(from: transcript)
                        if let weight = parsed.weight {
                            set.weight = WeightFormatter.displayString(weight)
                        }
                        if let reps = parsed.reps {
                            set.reps = String(reps)
                        }
                    }

                    if isFinal {
                        activeVoiceTarget = nil
                    }
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to start voice input."
                showErrorAlert = true
                activeVoiceTarget = nil
            }
        }
    }

    private func hasAnyLoggedValues(in routine: Routine, plan: ProgramWorkoutPlan) -> Bool {
        activeExercises(in: routine, plan: plan).contains { exercise in
            let sets = drafts[exercise.id] ?? []
            return sets.contains { set in
                !set.weight.isEmpty || !set.reps.isEmpty || !set.transcript.isEmpty
            }
        }
    }

    private func saveWorkout(routine: Routine, plan: ProgramWorkoutPlan) {
        let entries: [ExerciseEntry] = activeExercises(in: routine, plan: plan).map { exercise in
            let sets = (drafts[exercise.id] ?? []).compactMap { set -> ExerciseSet? in
                let transcript = set.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                let weight = Double(set.weight)
                let reps = Int(set.reps)

                if weight == nil, reps == nil, transcript.isEmpty {
                    return nil
                }

                return ExerciseSet(
                    weight: weight,
                    reps: reps,
                    transcript: transcript.isEmpty ? nil : transcript
                )
            }

            return ExerciseEntry(exerciseName: exercise.name, sets: sets)
        }

        store.logWorkout(routineID: routine.id, entries: entries)

        if autoStartRestTimer {
            startRestTimer(seconds: restTimerDuration)
        }

        speechInput.stopRecording()
        activeVoiceTarget = nil

        drafts = [:]
        syncSelection()

        showSavedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.savedToastDuration) {
            showSavedToast = false
        }
    }
}
