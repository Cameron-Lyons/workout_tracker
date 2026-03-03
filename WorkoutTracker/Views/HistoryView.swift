import Charts
import SwiftUI

private struct LiftProgressPoint: Identifiable {
    let sessionID: UUID
    let date: Date
    let topWeight: Double

    var id: UUID { sessionID }
}

private struct HistoryCachePayload {
    var workoutDays: Set<Date>
    var workoutCountByMonthStart: [Date: Int]
    var sessionsByWorkoutDay: [Date: [WorkoutSession]]
    var allSessionsNewestFirst: [WorkoutSession]
    var filteredSessions: [WorkoutSession]
}

struct HistoryView: View {
    private enum Constants {
        static let filterAnimation = Animation.easeInOut(duration: 0.22)
        static let weekDayCount = 7
        static let sessionEntrySpacing: CGFloat = 6
        static let sessionHeaderSpacing: CGFloat = 2
        static let calendarSectionSpacing: CGFloat = 12
        static let calendarGridColumnSpacing: CGFloat = 4
        static let calendarGridRowSpacing: CGFloat = 8
        static let calendarDayInnerSpacing: CGFloat = 3
        static let calendarDayMarkerSize: CGFloat = 6
        static let calendarDayMinHeight: CGFloat = 42
        static let calendarDayCornerRadius: CGFloat = 8
        static let selectedDayOpacity = 0.2
        static let todayOutlineOpacity = 0.7
        static let todayOutlineWidth: CGFloat = 1
        static let chartHeight: CGFloat = 220
        static let chartDesiredTickCount = 4
        static let emptyStateIcon = "calendar.badge.clock"
        static let emptyStateTitle = "No workouts logged yet"
        static let emptyStateMessage = "Your completed workouts and progress trends will appear here."
        static let emptyFilteredCardPadding: CGFloat = 14
        static let emptyFilteredCardCornerRadius: CGFloat = 14
        static let emptyFilteredTopInset: CGFloat = 6
        static let emptyFilteredBottomInset: CGFloat = 8
        static let standardHorizontalInset: CGFloat = 14
        static let entryCardCornerRadius: CGFloat = 14
        static let entryCardPadding: CGFloat = 14
        static let sessionSectionTopInset: CGFloat = 6
        static let sessionSectionBottomInset: CGFloat = 6
        static let sessionTitleFontSize: CGFloat = 20
        static let sessionScrollFadeOpacity = 0.84
        static let sessionScrollScale = 0.985
        static let sessionHeaderTopPadding: CGFloat = 16
        static let monthTitleFontSize: CGFloat = 22
        static let calendarCardCornerRadius: CGFloat = 16
        static let calendarCardPadding: CGFloat = 14
        static let calendarSectionInset: CGFloat = 8
        static let unselectedDayOpacity = 0.35
        static let progressSectionSpacing: CGFloat = 12
        static let progressCardCornerRadius: CGFloat = 16
        static let progressCardPadding: CGFloat = 14
        static let progressSectionInset: CGFloat = 8
        static let progressLineWidth: CGFloat = 2.5
        static let progressPointOpacity = 0.88
        static let progressAreaStartOpacity = 0.35
        static let progressAreaEndOpacity = 0.02
        static let cellSelectionAnimationDuration = 0.18
        static let overviewSectionInset: CGFloat = 8
    }

    @EnvironmentObject private var store: WorkoutStore
    @AppStorage(WeightUnit.preferenceKey) private var weightUnitRawValue = WeightUnit.pounds.rawValue
    @State private var selectedExerciseName = ""
    @State private var selectedCalendarDay: Date?
    @State private var displayedMonth = Date()
    @State private var hasInitializedCalendarMonth = false
    @State private var cachedWorkoutDays: Set<Date> = []
    @State private var cachedWorkoutCountByMonthStart: [Date: Int] = [:]
    @State private var cachedSessionsByWorkoutDay: [Date: [WorkoutSession]] = [:]
    @State private var cachedAllSessionsNewestFirst: [WorkoutSession] = []
    @State private var cachedFilteredSessions: [WorkoutSession] = []
    @State private var cachedProgressPointsByExerciseName: [String: [LiftProgressPoint]] = [:]
    @State private var cachedOrderedWeekdaySymbols: [String] = []
    @State private var cachedMonthGridDates: [Date?] = []
    @State private var historyCacheVersion = 0
    @State private var progressCacheVersion = 0
#if DEBUG
    @State private var showBenchmarkAlert = false
    @State private var benchmarkSummary = ""
#endif

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRawValue) ?? .pounds
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                Group {
                    if store.workoutHistory.isEmpty {
                        emptyState
                    } else {
                        let sessions = cachedFilteredSessions

                        List {
                            historyOverviewSection(filteredSessionCount: sessions.count)
                            calendarSection(filteredSessionCount: sessions.count)
                            progressSection

                            if sessions.isEmpty {
                                Section("Logged workouts") {
                                    Text("No workouts match the selected date.")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.textSecondary)
                                        .padding(Constants.emptyFilteredCardPadding)
                                        .appSurface(cornerRadius: Constants.emptyFilteredCardCornerRadius, shadow: false)
                                        .listRowBackground(Color.clear)
                                        .listRowInsets(
                                            EdgeInsets(
                                                top: Constants.emptyFilteredTopInset,
                                                leading: Constants.standardHorizontalInset,
                                                bottom: Constants.emptyFilteredBottomInset,
                                                trailing: Constants.standardHorizontalInset
                                            )
                                        )
                                        .listRowSeparator(.hidden)
                                }
                            } else {
                                ForEach(sessions) { session in
                                    Section {
                                        ForEach(session.entries) { entry in
                                            sessionEntryCard(entry)
                                                .scrollTransition(axis: .vertical) { content, phase in
                                                    content
                                                        .opacity(phase.isIdentity ? 1 : Constants.sessionScrollFadeOpacity)
                                                        .scaleEffect(phase.isIdentity ? 1 : Constants.sessionScrollScale)
                                                }
                                                .listRowBackground(Color.clear)
                                                .listRowSeparator(.hidden)
                                                .listRowInsets(
                                                    EdgeInsets(
                                                        top: Constants.sessionSectionTopInset,
                                                        leading: Constants.standardHorizontalInset,
                                                        bottom: Constants.sessionSectionBottomInset,
                                                        trailing: Constants.standardHorizontalInset
                                                    )
                                                )
                                        }
                                    } header: {
                                        sessionHeader(session)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.hidden)
                        .animation(Constants.filterAnimation, value: selectedCalendarDay)
                        .animation(Constants.filterAnimation, value: selectedExerciseName)
                    }
                }
            }
            .navigationTitle("History")
            .toolbarBackground(AppColors.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                rebuildHistoryCaches()
                syncExerciseSelection()
                rebuildProgressPointsCache()
            }
            .onChange(of: store.liftHistory) { _, _ in
                syncExerciseSelection()
                rebuildProgressPointsCache()
            }
            .onChange(of: store.workoutHistory) { _, _ in
                rebuildHistoryCaches()
            }
            .onChange(of: selectedCalendarDay) { _, _ in
                updateFilteredSessions()
            }
            .onChange(of: displayedMonth) { _, _ in
                rebuildCalendarGridCache()
            }
            .onChange(of: weightUnitRawValue) { _, _ in
                rebuildProgressPointsCache()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
                rebuildCalendarGridCache()
            }
            .tint(AppColors.accent)
#if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Benchmark") {
                        let historySummary = store.runHistoryQueryBenchmark()
                        let progressSummary = store.runProgressQueryBenchmark(unit: weightUnit)
                        benchmarkSummary = """
                        \(historySummary)

                        \(progressSummary)
                        """
                        showBenchmarkAlert = true
                    }
                }
            }
            .alert("History Query Benchmark", isPresented: $showBenchmarkAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(benchmarkSummary)
            }
#endif
        }
    }

    private var emptyState: some View {
        AppEmptyStateCard(
            systemImage: Constants.emptyStateIcon,
            title: Constants.emptyStateTitle,
            message: Constants.emptyStateMessage
        )
    }

    private func historyOverviewSection(filteredSessionCount: Int) -> some View {
        let selectedDayText = selectedCalendarDay?.formatted(date: .abbreviated, time: .omitted)
        let subtitle: String

        if let selectedDayText {
            subtitle = "Filtered to \(selectedDayText). Showing \(filteredSessionCount) workout\(filteredSessionCount == 1 ? "" : "s")."
        } else {
            subtitle = "Browse every logged session, calendar streaks, and top-set trends in one place."
        }

        return Section {
            AppHeroCard(
                eyebrow: "Session Archive",
                title: "\(store.workoutHistory.count) workouts logged",
                subtitle: subtitle,
                systemImage: "calendar.badge.clock",
                metrics: [
                    AppHeroMetric(
                        id: "history-sessions",
                        label: "Sessions",
                        value: "\(store.workoutHistory.count)",
                        systemImage: "clock.arrow.circlepath"
                    ),
                    AppHeroMetric(
                        id: "history-days",
                        label: "Active Days",
                        value: "\(workoutDays.count)",
                        systemImage: "calendar"
                    ),
                    AppHeroMetric(
                        id: "history-month",
                        label: monthTitle,
                        value: "\(workoutsInDisplayedMonth)",
                        systemImage: "calendar.badge.plus"
                    ),
                    AppHeroMetric(
                        id: "history-lifts",
                        label: "Tracked Lifts",
                        value: "\(trackedExercises.count)",
                        systemImage: "chart.line.uptrend.xyaxis"
                    )
                ]
            )
            .appReveal(delay: 0.02)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(
                EdgeInsets(
                    top: Constants.overviewSectionInset,
                    leading: Constants.standardHorizontalInset,
                    bottom: Constants.overviewSectionInset,
                    trailing: Constants.standardHorizontalInset
                )
            )
        }
    }

    private func sessionEntryCard(_ entry: ExerciseEntry) -> some View {
        VStack(alignment: .leading, spacing: Constants.sessionEntrySpacing) {
            Text(entry.exerciseName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textPrimary)

            if entry.sets.isEmpty {
                Text("No sets logged")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                    HStack {
                        Text("Set \(index + 1)")
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text(setSummary(set))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .font(.caption)
                }
            }
        }
        .padding(Constants.entryCardPadding)
        .appSurface(cornerRadius: Constants.entryCardCornerRadius, shadow: false)
    }

    private func sessionHeader(_ session: WorkoutSession) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: Constants.sessionHeaderSpacing) {
                Text(session.routineName)
                    .font(.system(size: Constants.sessionTitleFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                if let context = session.programContext, !context.isEmpty {
                    Text(context)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Text(session.performedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Label("\(session.entries.count)", systemImage: "dumbbell.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .appInsetCard(cornerRadius: 9, fillOpacity: 0.74, borderOpacity: 0.66)
        }
        .textCase(nil)
        .padding(.top, Constants.sessionHeaderTopPadding)
        .padding(.horizontal, Constants.standardHorizontalInset)
    }

    private var trackedExercises: [String] {
        store.exerciseNamesWithLiftHistory
    }

    private func selectedExerciseBinding(options: [String]) -> Binding<String> {
        Binding(
            get: {
                if options.contains(selectedExerciseName) {
                    return selectedExerciseName
                }
                return options.first ?? ""
            },
            set: { newValue in
                selectedExerciseName = newValue
            }
        )
    }

    private var calendar: Calendar {
        .autoupdatingCurrent
    }

    private var workoutDays: Set<Date> {
        cachedWorkoutDays
    }

    private var displayedMonthStart: Date {
        calendar.startOfMonth(for: displayedMonth)
    }

    private var monthBounds: (earliest: Date, latest: Date)? {
        guard let earliestDay = workoutDays.min(),
              let latestDay = workoutDays.max() else {
            return nil
        }

        return (
            earliest: calendar.startOfMonth(for: earliestDay),
            latest: calendar.startOfMonth(for: latestDay)
        )
    }

    private var canNavigateToPreviousMonth: Bool {
        guard let monthBounds else { return false }
        return displayedMonthStart > monthBounds.earliest
    }

    private var canNavigateToNextMonth: Bool {
        guard let monthBounds else { return false }
        return displayedMonthStart < monthBounds.latest
    }

    private var monthTitle: String {
        displayedMonthStart.formatted(.dateTime.month(.wide).year())
    }

    private var workoutsInDisplayedMonth: Int {
        cachedWorkoutCountByMonthStart[displayedMonthStart] ?? 0
    }

    private func calendarSection(filteredSessionCount: Int) -> some View {
        Section("Workout calendar") {
            VStack(spacing: Constants.calendarSectionSpacing) {
                HStack {
                    Button {
                        shiftDisplayedMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!canNavigateToPreviousMonth)

                    Spacer()

                    Text(monthTitle)
                        .font(.system(size: Constants.monthTitleFontSize, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Button {
                        shiftDisplayedMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!canNavigateToNextMonth)
                }

                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: Constants.calendarGridColumnSpacing),
                        count: Constants.weekDayCount
                    ),
                    spacing: Constants.calendarGridRowSpacing
                ) {
                    ForEach(Array(cachedOrderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(cachedMonthGridDates.enumerated()), id: \.offset) { _, date in
                        if let date {
                            calendarDayCell(for: date)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: Constants.calendarDayMinHeight)
                        }
                    }
                }

                if let selectedCalendarDay {
                    HStack(alignment: .firstTextBaseline) {
                        Text(
                            "Showing \(filteredSessionCount) workout\(filteredSessionCount == 1 ? "" : "s") on \(selectedCalendarDay.formatted(date: .abbreviated, time: .omitted))."
                        )
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)

                        Spacer()

                        Button("Show all") {
                            self.selectedCalendarDay = nil
                        }
                        .font(.caption.weight(.semibold))
                    }
                } else {
                    Text("Tap a marked day to filter workouts by date.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Constants.calendarCardPadding)
            .appSurface(cornerRadius: Constants.calendarCardCornerRadius, shadow: false)
            .appReveal(delay: 0.03)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(
                EdgeInsets(
                    top: Constants.calendarSectionInset,
                    leading: Constants.standardHorizontalInset,
                    bottom: Constants.calendarSectionInset,
                    trailing: Constants.standardHorizontalInset
                )
            )
        }
    }

    private func calendarDayCell(for date: Date) -> some View {
        let normalizedDate = calendar.startOfDay(for: date)
        let hasWorkout = workoutDays.contains(normalizedDate)
        let isSelected = selectedCalendarDay.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)

        return Button {
            selectedCalendarDay = normalizedDate
        } label: {
            VStack(spacing: Constants.calendarDayInnerSpacing) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline.weight(hasWorkout ? .semibold : .regular))
                    .foregroundStyle(hasWorkout ? AppColors.textPrimary : AppColors.textSecondary)

                Circle()
                    .fill(hasWorkout ? (isSelected ? AppColors.accent : AppColors.textSecondary) : Color.clear)
                    .frame(width: Constants.calendarDayMarkerSize, height: Constants.calendarDayMarkerSize)
            }
            .frame(maxWidth: .infinity, minHeight: Constants.calendarDayMinHeight)
            .background {
                RoundedRectangle(cornerRadius: Constants.calendarDayCornerRadius)
                    .fill(
                        isSelected
                            ? AppColors.accent.opacity(Constants.selectedDayOpacity)
                            : AppColors.surface.opacity(Constants.unselectedDayOpacity)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: Constants.calendarDayCornerRadius)
                    .stroke(
                        isToday ? AppColors.accent.opacity(Constants.todayOutlineOpacity) : Color.clear,
                        lineWidth: Constants.todayOutlineWidth
                    )
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: Constants.cellSelectionAnimationDuration), value: isSelected)
        .disabled(!hasWorkout)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(hasWorkout ? "Workout logged" : "No workout logged")
    }

    private func shiftDisplayedMonth(by offset: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonthStart) else {
            return
        }

        displayedMonth = calendar.startOfMonth(for: nextMonth)
    }

    private var selectedProgressPoints: [LiftProgressPoint] {
        cachedProgressPointsByExerciseName[selectedExerciseName] ?? []
    }

    private func trendSummary(for progressPoints: [LiftProgressPoint]) -> String? {
        guard let firstPoint = progressPoints.first else { return nil }
        let latestPoint = progressPoints.last ?? firstPoint
        let latestWeight = WeightFormatter.displayString(displayValue: latestPoint.topWeight, unit: weightUnit)

        if progressPoints.count < 2 {
            return "Latest top set: \(latestWeight) \(weightUnit.symbol) on \(latestPoint.date.formatted(date: .abbreviated, time: .omitted))."
        }

        let change = latestPoint.topWeight - firstPoint.topWeight
        let changePrefix = change >= 0 ? "+" : "-"
        let absoluteChange = WeightFormatter.displayString(displayValue: abs(change), unit: weightUnit)

        return "Change since first logged workout: \(changePrefix)\(absoluteChange) \(weightUnit.symbol) (\(firstPoint.date.formatted(date: .abbreviated, time: .omitted)) to \(latestPoint.date.formatted(date: .abbreviated, time: .omitted)))."
    }

    private var progressSection: some View {
        let exercises = trackedExercises
        let points = selectedProgressPoints
        let summary = trendSummary(for: points)

        return Section("Progress over time") {
            VStack(alignment: .leading, spacing: Constants.progressSectionSpacing) {
                if exercises.isEmpty {
                    Text("Log sets with weight to see progress over time.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    Picker("Exercise", selection: selectedExerciseBinding(options: exercises)) {
                        ForEach(exercises, id: \.self) { exerciseName in
                            Text(exerciseName).tag(exerciseName)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppColors.textPrimary)

                    if points.isEmpty {
                        Text("No weighted sets for this exercise yet.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        Chart(points) { point in
                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Top Weight (\(weightUnit.symbol))", point.topWeight)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        AppColors.accent.opacity(Constants.progressAreaStartOpacity),
                                        AppColors.accent.opacity(Constants.progressAreaEndOpacity)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Top Weight (\(weightUnit.symbol))", point.topWeight)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(
                                StrokeStyle(
                                    lineWidth: Constants.progressLineWidth,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                            .foregroundStyle(AppColors.accent)

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Top Weight (\(weightUnit.symbol))", point.topWeight)
                            )
                            .foregroundStyle(AppColors.accent.opacity(Constants.progressPointOpacity))
                        }
                        .frame(height: Constants.chartHeight)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: Constants.chartDesiredTickCount))
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .chartXAxisLabel(position: .bottom) {
                            Text("Date")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .chartYAxisLabel(position: .leading) {
                            Text("Top Weight (\(weightUnit.symbol))")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        if let summary {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }
            }
            .padding(Constants.progressCardPadding)
            .appSurface(cornerRadius: Constants.progressCardCornerRadius, shadow: false)
            .appReveal(delay: 0.08)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(
                EdgeInsets(
                    top: Constants.progressSectionInset,
                    leading: Constants.standardHorizontalInset,
                    bottom: Constants.progressSectionInset,
                    trailing: Constants.standardHorizontalInset
                )
            )
        }
    }

    private func setSummary(_ set: ExerciseSet) -> String {
        let weightText: String
        if let weight = set.weight {
            weightText = "\(WeightFormatter.displayString(weight, unit: weightUnit)) \(weightUnit.symbol)"
        } else {
            weightText = "-"
        }

        let repsText = set.reps.map(String.init) ?? "-"
        return "\(weightText) x \(repsText)"
    }

    private func syncExerciseSelection() {
        let options = trackedExercises
        guard !options.isEmpty else {
            selectedExerciseName = ""
            return
        }

        if options.contains(selectedExerciseName) == false {
            selectedExerciseName = options.first ?? ""
        }
    }

    private func rebuildHistoryCaches() {
        historyCacheVersion += 1
        let expectedVersion = historyCacheVersion
        let historySnapshot = store.workoutHistory
        let selectedDaySnapshot = selectedCalendarDay
        let calendarSnapshot = calendar

        DispatchQueue.global(qos: .userInitiated).async {
            let payload = Self.buildHistoryCaches(
                history: historySnapshot,
                selectedCalendarDay: selectedDaySnapshot,
                calendar: calendarSnapshot
            )

            DispatchQueue.main.async {
                guard self.historyCacheVersion == expectedVersion else {
                    return
                }

                self.cachedWorkoutDays = payload.workoutDays
                self.cachedWorkoutCountByMonthStart = payload.workoutCountByMonthStart
                self.cachedSessionsByWorkoutDay = payload.sessionsByWorkoutDay
                self.cachedAllSessionsNewestFirst = payload.allSessionsNewestFirst
                self.cachedFilteredSessions = payload.filteredSessions
                self.syncCalendarState()
                self.rebuildCalendarGridCache()
            }
        }
    }

    private func updateFilteredSessions() {
        guard let selectedCalendarDay else {
            cachedFilteredSessions = cachedAllSessionsNewestFirst
            return
        }

        let normalizedDay = calendar.startOfDay(for: selectedCalendarDay)
        cachedFilteredSessions = Array((cachedSessionsByWorkoutDay[normalizedDay] ?? []).reversed())
    }

    private func rebuildProgressPointsCache() {
        progressCacheVersion += 1
        let expectedVersion = progressCacheVersion
        let exercises = trackedExercises
        let unit = weightUnit
        var progressByExerciseNameSnapshot: [String: [LiftProgressSnapshot]] = [:]
        progressByExerciseNameSnapshot.reserveCapacity(exercises.count)
        for exerciseName in exercises {
            progressByExerciseNameSnapshot[exerciseName] = store.liftProgress(forExerciseName: exerciseName)
        }
        let progressByExerciseName = progressByExerciseNameSnapshot

        DispatchQueue.global(qos: .userInitiated).async {
            let refreshed = Self.buildProgressPointsCache(
                progressByExerciseName: progressByExerciseName,
                unit: unit
            )

            DispatchQueue.main.async {
                guard self.progressCacheVersion == expectedVersion else {
                    return
                }

                self.cachedProgressPointsByExerciseName = refreshed
            }
        }
    }

    private func syncCalendarState() {
        if hasInitializedCalendarMonth == false {
            if let latestWorkoutDate = store.workoutHistory.last?.performedAt {
                displayedMonth = calendar.startOfMonth(for: latestWorkoutDate)
            } else {
                displayedMonth = calendar.startOfMonth(for: Date())
            }
            hasInitializedCalendarMonth = true
        }

        let availableDays = workoutDays
        guard !availableDays.isEmpty else {
            selectedCalendarDay = nil
            return
        }

        if let selectedCalendarDay {
            let normalizedSelectedDate = calendar.startOfDay(for: selectedCalendarDay)
            self.selectedCalendarDay = availableDays.contains(normalizedSelectedDate) ? normalizedSelectedDate : nil
        }

        if let monthBounds {
            if displayedMonthStart < monthBounds.earliest {
                displayedMonth = monthBounds.earliest
            } else if displayedMonthStart > monthBounds.latest {
                displayedMonth = monthBounds.latest
            }
        }
    }

    private func rebuildCalendarGridCache() {
        cachedOrderedWeekdaySymbols = orderedWeekdaySymbols()
        cachedMonthGridDates = monthGridDates(for: displayedMonthStart)
    }

    private func orderedWeekdaySymbols() -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let startIndex = max(0, calendar.firstWeekday - 1)
        return (0..<symbols.count).map { symbols[(startIndex + $0) % symbols.count] }
    }

    private func monthGridDates(for monthStart: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthStart),
              let days = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingSlots = (firstWeekday - calendar.firstWeekday + Constants.weekDayCount) % Constants.weekDayCount
        var gridDates = Array(repeating: Date?.none, count: leadingSlots)

        for day in days {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
                gridDates.append(date)
            }
        }

        while gridDates.count % Constants.weekDayCount != 0 {
            gridDates.append(nil)
        }

        return gridDates
    }

    nonisolated private static func buildHistoryCaches(
        history: [WorkoutSession],
        selectedCalendarDay: Date?,
        calendar: Calendar
    ) -> HistoryCachePayload {
        var workoutDays: Set<Date> = []
        workoutDays.reserveCapacity(history.count)
        var workoutCountByMonthStart: [Date: Int] = [:]
        workoutCountByMonthStart.reserveCapacity(history.count)
        var sessionsByWorkoutDay: [Date: [WorkoutSession]] = [:]
        sessionsByWorkoutDay.reserveCapacity(history.count)

        for session in history {
            let workoutDay = calendar.startOfDay(for: session.performedAt)
            workoutDays.insert(workoutDay)
            sessionsByWorkoutDay[workoutDay, default: []].append(session)

            let monthStart = calendar.startOfMonth(for: session.performedAt)
            workoutCountByMonthStart[monthStart, default: 0] += 1
        }

        let allSessionsNewestFirst = Array(history.reversed())
        let filteredSessions: [WorkoutSession]
        if let selectedCalendarDay {
            let normalizedDay = calendar.startOfDay(for: selectedCalendarDay)
            filteredSessions = Array((sessionsByWorkoutDay[normalizedDay] ?? []).reversed())
        } else {
            filteredSessions = allSessionsNewestFirst
        }

        return HistoryCachePayload(
            workoutDays: workoutDays,
            workoutCountByMonthStart: workoutCountByMonthStart,
            sessionsByWorkoutDay: sessionsByWorkoutDay,
            allSessionsNewestFirst: allSessionsNewestFirst,
            filteredSessions: filteredSessions
        )
    }

    nonisolated private static func buildProgressPointsCache(
        progressByExerciseName: [String: [LiftProgressSnapshot]],
        unit: WeightUnit
    ) -> [String: [LiftProgressPoint]] {
        guard !progressByExerciseName.isEmpty else {
            return [:]
        }

        var refreshed: [String: [LiftProgressPoint]] = [:]
        refreshed.reserveCapacity(progressByExerciseName.count)

        for (exerciseName, snapshots) in progressByExerciseName {
            refreshed[exerciseName] = snapshots.map { progress in
                LiftProgressPoint(
                    sessionID: progress.sessionID,
                    date: progress.performedAt,
                    topWeight: unit.displayValue(fromStoredPounds: progress.topWeightInStoredPounds)
                )
            }
        }

        return refreshed
    }
}

private extension Calendar {
    func startOfMonth(for value: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: value)) ?? startOfDay(for: value)
    }
}
